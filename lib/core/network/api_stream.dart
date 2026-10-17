class ApiEventStream {
  ApiEventStream(this.bytes, this.close);
  final Stream<List<int>> bytes;
  final void Function() close;
}

class ApiDownload extends ApiEventStream {
  ApiDownload(super.bytes, super.close, this.contentLength);
  final int contentLength;
}
