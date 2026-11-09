//! Detached appearance work on the host's background executor.

/// Runs work on Rayon natively; the browser runs it inline because Rayon's thread-less wasm
/// fallback never executes `spawn`ed jobs, which left remote player skins unprepared forever.
pub(crate) fn detach(job: impl FnOnce() + Send + 'static) {
    #[cfg(not(target_arch = "wasm32"))]
    rayon::spawn(job);
    #[cfg(target_arch = "wasm32")]
    job();
}
