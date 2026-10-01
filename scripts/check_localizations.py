#!/usr/bin/env python3
# coding: utf-8
"""Validate shipped localization coverage and printf argument safety. No network."""
from pathlib import Path
import json, re, subprocess, collections, sys
ROOT = Path(__file__).resolve().parents[1]
def literals(s):
 i=0
 while i<len(s):
  if s.startswith('//',i):
   j=s.find('\n',i); i=len(s) if j<0 else j; continue
  if s.startswith('/*',i):
   depth=1; i+=2
   while i<len(s) and depth:
    if s.startswith('/*',i):depth+=1;i+=2
    elif s.startswith('*/',i):depth-=1;i+=2
    else:i+=1
   continue
  if s[i]=='"':
   start=i; delim='"""' if s.startswith('"""',i) else '"'; i+=len(delim)
   while i<len(s):
    if s.startswith('\\(',i):
     depth=1;i+=2
     while i<len(s) and depth:
      if s[i]=='"':
       i+=1
       while i<len(s) and s[i]!='"':
        i+=2 if s[i]=='\\' else 1
       i+=1
      elif s[i]=='(':depth+=1;i+=1
      elif s[i]==')':depth-=1;i+=1
      else:i+=1
    elif s[i]=='\\':i+=2
    elif s.startswith(delim,i):i+=len(delim);break
    else:i+=1
   yield start,i,s[start:i]
  else:i+=1
def key_for(lit):
 s=lit[1:-1];parts=[];i=0;n=0
 while i<len(s):
  if s.startswith('\\(',i):
   n+=1;parts.append(f'%{n}$@');i+=2;depth=1
   while i<len(s) and depth:
    if s[i]=='"':
     i+=1
     while i<len(s) and s[i]!='"':i+=2 if s[i]=='\\' else 1
     i+=1
    elif s[i]=='(':depth+=1;i+=1
    elif s[i]==')':depth-=1;i+=1
    else:i+=1
  elif s.startswith('\\n',i):parts.append('\n');i+=2
  elif s.startswith('\\"',i):parts.append('"');i+=2
  elif s.startswith('\\\\',i):parts.append('\\');i+=2
  else:
   parts.append('%%' if s[i]=='%' and '\\(' in s else s[i]);i+=1
 return ''.join(parts)

def read_strings(path):
    result = subprocess.run(["plutil", "-convert", "json", "-o", "-", str(path)], capture_output=True, text=True, check=True)
    return json.loads(result.stdout)

def main():
    resources = ROOT / "FaceRate/Resources"
    english = read_strings(resources / "en.lproj/Localizable.strings")
    errors = []
    languages = ["en", "tr", "es", "pt-BR", "fr", "de", "ru", "ar", "hi", "zh-Hans", "ja"]
    # Only the conversion types used by this catalog; literal prose such as
    # "50% de descuento" must not be interpreted as a padded %d conversion.
    token = re.compile(r"%(?:\d+\$)?(?:@|lld|(?:\.\d+)?f)")
    for language in languages:
        folder = resources / (language + ".lproj")
        entries = read_strings(folder / "Localizable.strings")
        if entries.keys() != english.keys(): errors.append(language + ": mismatched key set")
        for key, value in entries.items():
            if not value.strip() or "\ufffd" in value: errors.append(language + ": empty/damaged " + key)
            if collections.Counter(token.findall(key)) != collections.Counter(token.findall(value)):
                errors.append(language + ": arguments changed: " + key)
            if token.search(key):
                # Consume escapes and typed slots; remaining percent signs are unsafe.
                rest = re.sub(r"%%|" + token.pattern, "", value)
                if "%" in rest: errors.append(language + ": unsafe format: " + key)
        info = read_strings(folder / "InfoPlist.strings")
        for key in ["NSCameraUsageDescription", "NSPhotoLibraryUsageDescription"]:
            if not info.get(key): errors.append(language + ": missing permission " + key)
    for path in (ROOT / "FaceRate").rglob("*.swift"):
        if " 2.swift" in path.name or path.name == "L10n.swift": continue
        text = path.read_text()
        for a, b, literal in literals(text):
            prefix = text[max(0, a-100):a]
            if re.search(r"(?:L10n\.text|NSLocalizedString)\(\s*$", prefix):
                key = key_for(literal)
                if key not in english: errors.append(str(path.relative_to(ROOT)) + ": missing key " + repr(key))
            elif re.search(r"(?:title|subtitle|caption|bodyText|message|detail|eyebrow|kicker|text):\s*$", prefix):
                plain = literal[1:-1]
                if re.search("[A-Za-z]{2}", plain) and "\\(" not in plain and plain not in english:
                    errors.append(str(path.relative_to(ROOT)) + ": uncovered UI text " + plain)
            elif re.search(r"label:\s*$", prefix) and path.name != "CaptureService.swift":
                plain = literal[1:-1]
                if re.search("[A-Za-z]{2}", plain) and "\\(" not in plain and plain not in english:
                    errors.append(str(path.relative_to(ROOT)) + ": uncovered label " + plain)
    if errors:
        print("\n".join(errors)); return 1
    print(f"PASS: {len(english)} keys in {len(languages)} languages; arguments, source coverage and permissions verified.")
    return 0
if __name__ == "__main__": sys.exit(main())
