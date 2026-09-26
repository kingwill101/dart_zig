/// Runtime unit tests inject their own wake callback and do not load Dart.
pub fn wake(_: i64) bool {
    @panic("A runtime test did not inject a wake callback");
}
