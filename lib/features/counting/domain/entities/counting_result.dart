class CountingResult {
  final Map<int, int> classCounts; // classId -> total count
  final Set<int> countedTrackIds; // trackId set of objects that crossed

  const CountingResult({
    this.classCounts = const {},
    this.countedTrackIds = const {},
  });

  CountingResult copyWith({
    Map<int, int>? classCounts,
    Set<int>? countedTrackIds,
  }) {
    return CountingResult(
      classCounts: classCounts ?? this.classCounts,
      countedTrackIds: countedTrackIds ?? this.countedTrackIds,
    );
  }
}
