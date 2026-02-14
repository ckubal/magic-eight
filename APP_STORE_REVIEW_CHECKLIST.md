# Magic Eight App Store Review Checklist

Use this before submitting each build to App Review.

## In-App Readiness

- [ ] `Settings` shows a valid, public privacy policy link.
- [ ] `Settings` shows a valid terms of use link (recommended).
- [ ] `Settings` shows a support contact path (`mailto:` link is present).
- [ ] App launches and core flow works without crashes on a physical device.
- [ ] Orientation, motion behavior, and onboarding are stable across supported devices.

## App Store Connect Metadata (Required/Expected)

- [ ] **Privacy Policy URL** is set to a public page.
- [ ] **Support URL** is set to a public support/contact page.
- [ ] App Privacy questionnaire is completed accurately.
- [ ] Category, age rating, and app description match actual app behavior.
- [ ] Screenshots accurately show the current UI and features.

## Data & Privacy Declaration

Current app behavior to account for in App Privacy answers:

- Stores selected response set locally (`UserDefaults`).
- Fetches response packs from `https://www.weirdlittleideas.com/builds/magiceight/responses.json`.
- Uses Core Motion accelerometer on device for interaction.

If you do not collect user-linked data server-side, your privacy answers will likely be minimal, but they still must be completed and accurate.

## Build/Release Hygiene

- [ ] `MARKETING_VERSION` and `CURRENT_PROJECT_VERSION` are updated for this release.
- [ ] Deployment target is intentionally set (currently high in project settings).
- [ ] Archive validates cleanly in Organizer.
- [ ] Any non-obvious behavior is explained in Review Notes.
