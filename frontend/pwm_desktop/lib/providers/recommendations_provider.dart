import 'package:flutter/material.dart';

import '../models/models.dart';
import '../utils/api_client_exception.dart';
import 'base_provider.dart';
import 'project_category_provider.dart';

enum RecommendationsStatusState { idle, loading, ready, failed }

/// The Project Resource Estimation screen's own store. It holds what the office
/// typed in; the estimate itself is not computed yet.
///
/// **There is no estimator behind this screen.** The API has no endpoint for it
/// and nothing here derives one, so [hasEstimate] is always false and the cards
/// and the work-type table stay empty. This class is the seam: when the model
/// lands, [estimate] is what calls it and fills [totalHours] and the rest.
class RecommendationsProvider extends ChangeNotifier {
  RecommendationsProvider({BaseProvider<ProjectCategory>? categories})
      : _categories = categories ?? ProjectCategoryProvider();

  final BaseProvider<ProjectCategory> _categories;

  RecommendationsStatusState _status = RecommendationsStatusState.idle;
  String? _errorMessage;

  List<ProjectCategory> _categoryList = const [];

  int? _categoryId;
  double? _tonnes;
  int? _workingDays;

  /// Set once Estimate has been pressed, so the empty state can say why there is
  /// nothing rather than looking like it is still loading.
  bool _asked = false;

  RecommendationsStatusState get status => _status;
  String? get errorMessage => _errorMessage;

  List<ProjectCategory> get categories => _categoryList;

  int? get categoryId => _categoryId;
  double? get tonnes => _tonnes;
  int? get workingDays => _workingDays;

  bool get asked => _asked;

  /// True once an estimator exists and has answered. Nothing sets it yet.
  bool get hasEstimate => false;

  /// Every input the estimator will need is filled in.
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

  void estimate() {
    _asked = true;
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
