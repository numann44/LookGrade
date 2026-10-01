# LookGrade legal and support site

The privacy policy, terms of use, and support landing page are maintained in the
same repository as the iOS app. The former `numann44/lookgrade-legal` repository
has been consolidated here. The policy and terms text are preserved.

## Public URLs

- Support: <https://numann44.github.io/LookGrade/>
- Privacy: <https://numann44.github.io/LookGrade/privacy.html>
- Terms: <https://numann44.github.io/LookGrade/terms.html>

`FaceRate/App/LegalLinks.swift` supplies the in-app URLs used by the paywall and
profile. Keep those values aligned with the published site.

## Deployment

The [Pages workflow](../.github/workflows/legal-pages.yml) publishes only this
directory. Pushes to `main` that change this directory or the workflow trigger a
deployment; it can also be run manually. Repository Settings → Pages must use
**GitHub Actions** as the source. No custom domain or build tool is required.

## Preview locally

From the repository root:

```sh
python3 -m http.server 8080 --directory LegalSite
```

Open <http://localhost:8080/> and check the navigation, both policies, and support
email link before publishing.

## App release migration

Changing source code does not rewrite installed App Store binaries. Versions
containing the old `lookgrade-legal` URLs need an app update to use the new links.
The old site URL stops working after the separate repository is deleted; GitHub
Pages does not redirect that URL to this site automatically.

Update the Privacy Policy URL, Support URL, and any Terms links in App Store
Connect metadata to the URLs above. Metadata changes and submission of an app
update are separate release operations.
