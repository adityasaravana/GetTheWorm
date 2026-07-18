# GetTheWorm 🪱

A free, open-source alarm clock for iOS in the spirit of [erly](https://erly.app). The alarm does not stop until you go outside and take a photo of real grass.

<p>
  <img src="docs/clock.png" width="300" alt="The clock radio home screen">
  <img src="docs/victory.png" width="300" alt="The victory screen">
</p>

## How it works

- You set one wake-up alarm and pick your weekdays on a bank of DIP switches.
- At wake time, GetTheWorm has already queued about 30 alarms with iOS, one minute apart, using AlarmKit (new in iOS 26). They ring through Silent Mode and Focus.
- The stop button on the lock screen is futile. The rest of the chain is already scheduled with the system, so another alarm arrives a minute later. Force quitting the app does not help either.
- The only way out is to open the app and photograph grass. A live camera shot is classified on device with the Vision framework. Real grass passes, houseplants and green carpets do not. Nothing leaves your phone.
- Succeed and you get the worm. The remaining alarms are cancelled and tomorrow's chain is queued.

There is no escape hatch. Worst case, the chain gives up after 30 minutes, and you have to live with that.

## Requirements

- iOS 26 or later (AlarmKit)
- Xcode 26 to build
- A real iPhone for the full experience. The camera and the Vision classifier both need real hardware.

## Building

Open `GetTheWorm/GetTheWorm.xcodeproj` and hit run. No dependencies, no accounts, no servers.

On the simulator the camera does not exist and the Vision classifier cannot run (it fails to create an inference context), so the ringing screen shows a picker of bundled test photos instead. Their filenames carry the ground truth. On a device, the real classifier runs.

`tools/classify-fixtures.swift` runs the same classifier on macOS if you want to tune the confidence threshold against your own photos.

## Testing

Unit tests cover the alarm date math (including DST and window edge cases), display formatting, and the grass classifier verdicts on the bundled fixture photos. The classifier tests only run on a real device, for the reason above.

## Credits

- Inspired by [erly](https://erly.app). Not affiliated, just fans of being forced to touch grass.
- 7-segment and 14-segment fonts: [DSEG](https://github.com/keshikan/DSEG) by keshikan, SIL Open Font License.
- Test photos from Wikimedia Commons, see `GetTheWorm/GetTheWorm/Resources/TestPhotos/ATTRIBUTION.md`.

## License

MIT. See [LICENSE](LICENSE).
