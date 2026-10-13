/// Per-image upload status, surfaced directly in the Upload Manager screen.
enum UploadStatus {
  /// Queued, no upload attempt has run yet (or a previous attempt failed and
  /// it is waiting to be retried).
  pending,

  /// An upload attempt is currently in flight.
  uploading,

  /// Uploaded successfully.
  synced,

  /// The most recent attempt failed; still queued for retry.
  failed,
}

/// Whether a batch is still accepting new captures or has been handed off
/// for upload.
enum BatchStatus {
  /// The user can still add images to this batch.
  capturing,

  /// The batch was finalized ("Upload Batch" tapped) and its images are now
  /// in the upload queue.
  finalized,
}
