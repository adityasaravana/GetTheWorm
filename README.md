# GetTheWorm 🪱

An open-source alarm clock for iOS inspired by [erly](https://erly.app). It won't stop ringing until you go outside and take a photo of real grass.

<p>
  <img src="docs/clock.png" width="300" alt="The clock radio home screen">
  <img src="docs/victory.png" width="300" alt="The victory screen">
</p>

## How it works

1. Set one wake-up alarm and pick your weekdays with the DIP switches.
2. At wake time, the app has already queued about 30 alarms with iOS, one minute apart, using AlarmKit (new in iOS 26). They ring through Silent Mode and Focus.
3. Dismissing one alarm doesn't help. The rest of the chain is already scheduled with the system, so another one shows up a minute later. Force quitting doesn't help either.
4. To actually stop the alarms, open the app and photograph some grass. A live camera shot is classified on-device with the Vision framework. Real grass passes; houseplants and green carpets don't. Nothing leaves your phone.
5. Once you pass, the remaining alarms are cancelled and tomorrow's chain is queued.

If you really can't get outside, the chain gives up after 30 minutes.

## Requirements

- iOS 26 or later (AlarmKit)
- Xcode 26 to build
- A real iPhone for the full experience (the camera and the Vision classifier both need real hardware)

## Building

Open `GetTheWorm/GetTheWorm.xcodeproj` and hit run. No dependencies, no accounts, no servers.

On the simulator, the camera doesn't exist and the Vision classifier can't run, so the ringing screen shows a picker of bundled test photos instead. Their filenames carry the ground truth. On a device, the real classifier runs.

`tools/classify-fixtures.swift` runs the same classifier on macOS if you want to tune the confidence threshold against your own photos.

## Testing

Unit tests cover the alarm date math (including DST and window edge cases), display formatting, and the grass classifier verdicts on the bundled fixture photos. The classifier tests only run on a real device for the reason above.

## Credits

- Inspired by [erly](https://erly.app). Not affiliated, just fans of being forced to touch grass.
- 7-segment and 14-segment fonts: [DSEG](https://github.com/keshikan/DSEG) by keshikan, SIL Open Font License.
- Test photos from Wikimedia Commons, see `GetTheWorm/GetTheWorm/Resources/TestPhotos/ATTRIBUTION.md`.

## License

MIT. See [LICENSE](LICENSE).
