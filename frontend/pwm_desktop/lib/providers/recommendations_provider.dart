import 'package:flutter/material.dart';

import '../models/models.dart';
import '../utils/api_client_exception.dart';
import 'base_provider.dart';
import 'project_category_provider.dart';
import 'recommendation_api_provider.dart';

enum RecommendationsStatusState { idle, loading, ready, failed }

/// The Project Resource Estimation screen's own store. It holds what the office
/// typed in and, once Estimate is pressed, the answer from `POST
/// /Recommendation/Estimate` - see `RecommendationService` on the API for how
/// that answer is worked out.
class RecommendationsProvider extends ChangeNotifier {
  RecommendationsProvider({
    BaseProvider<ProjectCategory>? categories,
    RecommendationApiProvider? recommendationApi,
  })  : _categories = categories ?? ProjectCategoryProvider(),
        _recommendationApi = recommendationApi ?? RecommendationApiProvider();

  final BaseProvider<ProjectCategory> _categories;
  final RecommendationApiProvider _recommendationApi;

  RecommendationsStatusState _status = RecommendationsStatusState.idle;
  String? _errorMessage;

  List<ProjectCategory> _categoryList = const [];

  int? _categoryId;
  double? _tonnes;
  int? _workingDays;

  /// Set once Estimate has been pressed, so the empty state can say why there is
  /// nothing rather than looking like it is still loading.
  bool _asked = false;

  bool _estimating = false;
  String? _estimateError;
  RecommendationResult? _result;

  RecommendationsStatusState get status => _status;
  String? get errorMessage => _errorMessage;

  List<ProjectCategory> get categories => _categoryList;

  int? get categoryId => _categoryId;
  double? get tonnes => _tonnes;
  int? get workingDays => _workingDays;

  bool get asked => _asked;
  bool get estimating => _estimating;
  String? get estimateError => _estimateError;

  /// True once the API has answered with an estimate it could compute.
  bool get hasEstimate => _result?.hasEstimate ?? false;

  /// Set when the API answered but the category has too little history yet.
  String? get noDataMessage => _result != null && !_result!.hasEstimate ? _result!.message : null;

  int get sampleSize => _result?.sampleSize ?? 0;
  double get accuracyPercent => _result?.accuracyPercent ?? 0;

  /// Set only when [hasEstimate] is true - the plain-language "why" behind the numbers.
  String? get explanation => _result != null && _result!.hasEstimate ? _result!.explanation : null;
  double get totalHours => _result?.totalHours ?? 0;
  int get estimatedWorkers => _result?.estimatedWorkers ?? 0;
  int get estimatedDurationDays => _result?.estimatedDurationDays ?? 0;
  List<RecommendationWorkType> get workTypes => _result?.workTypes ?? const [];

  /// Every input the estimator needs is filled in.
  bool get canEstimate =>
      _categoryId != null && (_tonnes ?? 0) > 0 && (_workingDays ?? 0) > 0;

  void setCategory(int? id) {
    _categoryId = id;
    notifyListeners();
  }

  void setTonnes(String value) {
    _tonnes = double.tryParse(value.replaceAll(',', '.'));
    notifyListeners();
  }

  void setWorkingDays(String value) {
    _workingDays = int.tryParse(value.trim());
    notifyListeners();
  }

  Future<void> estimate() async {
    if (!canEstimate) return;

    _asked = true;
    _estimating = true;
    _estimateError = null;
    notifyListeners();

    try {
      _result = await _recommendationApi.estimate(
        projectCategoryId: _categoryId!,
        tonnes: _tonnes!,
        workingDays: _workingDays!,
      );
    } on ApiClientException catch (error) {
      _result = null;
      _estimateError = error.message;
    } catch (error) {
      _result = null;
      _estimateError = 'Something went wrong while estimating: $error';
    }

    _estimating = false;
    notifyListeners();
  }

  Future<void> load() async {
    _status = RecommendationsStatusState.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      final categories = await _categories.getAll();
      _categoryList = categories..sort((a, b) => a.name.compareTo(b.name));

      _status = RecommendationsStatusState.ready;
    } on ApiClientException catch (error) {
      _errorMessage = error.message;
      _status = RecommendationsStatusState.failed;
    } catch (error) {
      _errorMessage = 'Something went wrong while loading project types: $error';
      _status = RecommendationsStatusState.failed;
    }

    notifyListeners();
  }
}
