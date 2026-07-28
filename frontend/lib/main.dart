import 'package:flutter/material.dart';

import 'app/app.dart';
import 'app/router.dart';
import 'data/repositories/anomaly_repository.dart';
import 'data/repositories/auth_repository.dart';
import 'data/repositories/connection_repository.dart';
import 'data/repositories/dashboard_repository.dart';
import 'data/repositories/extended_finance_repository.dart';
import 'data/repositories/household_repository.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  final authRepository = AuthRepository();
  final householdRepository = HouseholdRepository(
    authRepository: authRepository,
  );
  final connectionRepository = ConnectionRepository(
    authRepository: authRepository,
  );
  final dashboardRepository = DashboardRepository(
    authRepository: authRepository,
  );
  final financeRepository = ExtendedFinanceRepository(
    authRepository: authRepository,
  );
  final anomalyRepository = AnomalyRepository(authRepository: authRepository);

  authRepository.restoreSession();

  runApp(
    FamilyFinanceApp(
      router: buildRouter(
        authRepository: authRepository,
        householdRepository: householdRepository,
        connectionRepository: connectionRepository,
        dashboardRepository: dashboardRepository,
        financeRepository: financeRepository,
        anomalyRepository: anomalyRepository,
      ),
    ),
  );
}
