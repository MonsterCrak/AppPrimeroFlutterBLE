/// 1D Kalman filter for smoothing scalar time-series signals.
///
/// Optimal recursive estimator for a single hidden state with Gaussian
/// noise. Used here to smooth RSSI readings from BLE beacons — each
/// ranging event carries 3-7 dBm of jitter from multipath, antenna
/// orientation, and body absorption, which makes the position jump
/// visibly from frame to frame. The Kalman filter produces a stable,
/// responsive estimate by trading a small lag for noise rejection.
///
/// State model (random walk):
///   x_k = x_{k-1} + w_k,   w_k ~ N(0, q)
///
/// Measurement model:
///   z_k = x_k + v_k,        v_k ~ N(0, r)
///
/// where:
///   - [q] is process noise variance (how much the true RSSI can drift
///     between samples). Higher q → trust measurements more → less
///     smoothing, faster response to real changes.
///   - [r] is measurement noise variance (raw RSSI sensor noise).
///     Higher r → trust measurements less → more smoothing, slower
///     response to real changes.
///
/// For indoor BLE RSSI at ~1 Hz:
///   - q ≈ 1-4 dBm²  (true value drifts ±1-2 dBm between samples)
///   - r ≈ 9-25 dBm² (raw RSSI has σ ≈ 3-5 dBm)
///
/// Defaults q=2.0, r=16.0 are reasonable starting points.
library;

class KalmanFilter1D {
  /// Process noise variance. True RSSI drift between samples.
  final double q;

  /// Measurement noise variance. Raw RSSI sensor noise.
  final double r;

  double _x = 0;
  double _p = 1;
  bool _initialized = false;

  KalmanFilter1D({this.q = 2.0, this.r = 16.0});

  /// Process a new measurement, return the smoothed estimate.
  ///
  /// First call initializes the filter to the measurement value with
  /// uncertainty [r]. Subsequent calls run the standard predict-update
  /// cycle:
  ///
  ///   predict:  p_pred = p + q
  ///   gain:     k = p_pred / (p_pred + r)
  ///   update:   x = x + k * (z - x)
  ///             p = (1 - k) * p_pred
  double update(double measurement) {
    if (!_initialized) {
      _x = measurement;
      _p = r; // initial uncertainty equals measurement noise
      _initialized = true;
      return _x;
    }

    // Predict: state is constant; add process-noise growth to covariance.
    final pPred = _p + q;

    // Update: blend prediction with measurement via optimal Kalman gain.
    final k = pPred / (pPred + r);
    _x = _x + k * (measurement - _x);
    _p = (1 - k) * pPred;

    return _x;
  }

  /// Reset the filter to uninitialized state. Next [update] starts fresh.
  void reset() {
    _initialized = false;
    _p = r;
  }

  /// Current smoothed estimate. Returns `0` if not yet initialized — call
  /// [update] at least once before reading this.
  double get value => _x;

  /// True after the first [update] call.
  bool get isInitialized => _initialized;
}