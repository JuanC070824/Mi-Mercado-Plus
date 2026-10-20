import '../../core/config/api_config.dart';
import 'canasta_api_repository.dart';
import 'canasta_repository.dart';

CanastaRepository get canastaApp => ApiConfig.configurada
    ? CanastaApiRepository.instancia
    : CanastaRepositoryMock.instancia;
