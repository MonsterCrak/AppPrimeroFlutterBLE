# Project Status — Snapshot 2026-05-30

> Mirror of `E:\Obsidian\Tesis\Emulador BLE Indoor\Estado del Proyecto.md`.

## TL;DR

- **120/120 tests passing.**
- **`flutter analyze` clean.**
- **APK debug compiles for Android.**
- **One known bug**: in Real BLE mode the user-position dot doesn't move when walking around the house. See WU-16 in `Plan.md` for the fix.

## WUs Delivered (16 total)

| WU | Status | Commit |
|----|--------|--------|
| WU-0 Bootstrap | ✅ | `2bc3691` |
| WU-1 Domain models | ✅ | `0c53785` |
| WU-2 House + 3 beacons | ✅ | `8880037` |
| WU-3 Vector render | ✅ | `e938756` |
| WU-4 RSSI model | ✅ | `1580f4e` |
| WU-5 Simulated source | ✅ | `30fe535` |
| WU-6 Simulation notifier | ✅ | `f901145` |
| WU-7 User + route render | ✅ | `6444586` |
| WU-8 Telemetry panel | ✅ | `10139fb` |
| WU-9 Start/stop control | ✅ | `421a078` |
| WU-10 HomeScreen polish | ✅ | `2d99f79` |
| WU-11 Permissions | ✅ | `9825a88`, `d331816`, `9d79cdf` |
| WU-12 BLE source | ✅ | `3495d6c` |
| WU-13 Mode selector | ✅ | `de975ca` |
| WU-14 Manual mapping | ⏭️ Skipped (auto-mapped by Minor) | — |
| WU-15 BLE error handling | ✅ | `d36d4f9` |
| WU-15b (bug) Position frozen in Real BLE | 🐞 Pending | — |
| WU-16 Trilateration (weighted centroid) | ⏳ Next | — |

## Known Bugs

### WU-15b — Position doesn't update in Real BLE mode

**Symptom:** When the user activates Real BLE and walks around the house, the blue dot (user position) does NOT move. Only the simulated mode animates the position via the timer + waypoints.

**Cause:** `SimulationNotifier.stop()` is called when switching to Real BLE. The position only updates when there's input (timer in Sim, `setUserPosition` in tests). The BLE source emits RSSI per beacon — it does NOT compute a position.

**Impact:** Telemetry shows real RSSI correctly, but no visual tracking of the user's movement.

**Fix (WU-16):** Compute user position as a weighted centroid of the 3 beacons (weight ∝ 1/distance²). Trigger the recomputation from the BLE source's `changes` stream when `mode == realBle`.

## Hardware Validation (passed)

- 3× FSC-BP104D beacons in pure iBeacon mode.
- Proximity UUID: `fda50693-a4e2-4fb1-afcf-c6eb07647825`.
- Major: `10065` (all 3).
- Minor: `1` (Sala), `2` (Pasadizo), `3` (Padres).
- TxPower: `-59 dBm` calibrated at 1 m.
- Confirmed visible in **nRF Connect** on the Infinix X6873 (Android 16).

## Next Steps

1. **WU-16** (~30 min implementation + tests): trilateration for Real BLE mode.
2. **E2E verification**: `flutter run -d 1433825558110713`, walk around, see blue dot move.
3. **iOS build**: when you have a Mac, `flutter build ios` (only software changes needed; hardware works on iOS too thanks to `dchs_flutter_beacon` using CoreLocation).
4. **Final README** with deployment instructions.

## References

- Plan: `E:\Obsidian\Tesis\Emulador BLE Indoor\Plan.md`
- Architecture: `E:\Obsidian\Tesis\Emulador BLE Indoor\Arquitectura.md`
- Beacon distribution: `E:\Obsidian\Tesis\Emulador BLE Indoor\Distribucion Mi Casa.md`
- Repo: https://github.com/MonsterCrak/AppPrimeroFlutterBLE