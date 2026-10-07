enum EngineModel { light, full }

class EngineConfiguration {
  const EngineConfiguration({this.model = EngineModel.light, this.nnuePath});
  final EngineModel model;
  final String? nnuePath;

  String get name => model == EngineModel.full ? 'Stockfish 19' : 'Stockfish 19 Light';

  @override
  bool operator ==(Object other) => other is EngineConfiguration && model == other.model && nnuePath == other.nnuePath;
  @override
  int get hashCode => Object.hash(model, nnuePath);
}
