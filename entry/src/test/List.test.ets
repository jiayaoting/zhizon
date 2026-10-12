// 智子 - 本地单元测试入口（hypium）
// hvigorw test 会编译并调用本文件的 default 导出（testsuite）；
// 各测试文件通过 default 导出一个注册函数，在此统一注册。
import DefectClassifierTest from './DefectClassifierTest';
import DefectWorkflowTest from './DefectWorkflowTest';
import GameLaunchFacadeTest from './GameLaunchFacadeTest';
import HotDataProviderTest from './HotDataProviderTest';
import HotModuleTest from './HotModuleTest';
import LlmProviderTest from './LlmProviderTest';
import NavigationFacadeTest from './NavigationFacadeTest';
import NewsNowClientTest from './NewsNowAuthTest';
import NewsRepositoryTest from './NewsRepositoryTest';
import SudokuSolverTest from './SudokuSolverTest';
import WindowEnvironmentProviderTest from './WindowEnvironmentProviderTest';
import WindowEnvironmentSnapshotTest from './WindowEnvironmentSnapshotTest';

export default function testsuite() {
  DefectClassifierTest();
  DefectWorkflowTest();
  GameLaunchFacadeTest();
  HotDataProviderTest();
  HotModuleTest();
  LlmProviderTest();
  NavigationFacadeTest();
  NewsNowClientTest();
  NewsRepositoryTest();
  SudokuSolverTest();
  WindowEnvironmentProviderTest();
  WindowEnvironmentSnapshotTest();
}
