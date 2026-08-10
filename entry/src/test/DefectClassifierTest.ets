import { describe, it, expect } from '@ohos/hypium';
import { AffectedFeature, DefectInput, DefectSeverity } from '../main/ets/model/GovernanceModels';
import { DefectClassifier } from '../main/ets/service/DefectClassifier';

export default function DefectClassifierTest() {
  describe('DefectClassifierTest', () => {
    it('prioritizes startup and data security as blocking', 0, () => {
      const startup = new DefectInput('启动失败', '页面未打开', ['已安装'], ['启动应用'], '显示首页',
        '停留启动页', 'phone', 'test', [AffectedFeature.STARTUP]);
      const security = new DefectInput('凭据泄露', '日志含令牌', ['已连接'], ['查看日志'], '隐藏令牌',
        '显示令牌', 'phone', 'test', [AffectedFeature.DATA_SECURITY]);
      expect(DefectClassifier.classify(startup).severity).assertEqual(DefectSeverity.BLOCKING);
      expect(DefectClassifier.classify(startup).priority).assertEqual(1);
      expect(DefectClassifier.classify(security).priority).assertEqual(1);
    });

    it('orders remote page and minor defects by impact', 0, () => {
      const remote = new DefectInput('连接失败', '无法连接', ['有服务器'], ['点击连接'], '建立连接',
        '连接超时', 'phone', 'test', [AffectedFeature.REMOTE]);
      const page = new DefectInput('页面异常', '内容缺失', ['已进入'], ['刷新'], '显示内容',
        '内容为空', 'phone', 'test', [AffectedFeature.PAGE]);
      const theme = new DefectInput('颜色异常', '颜色偏差', ['已启动'], ['切换主题'], '正确颜色',
        '颜色错误', 'phone', 'test', [AffectedFeature.THEME]);
      expect(DefectClassifier.classify(remote).severity).assertEqual(DefectSeverity.CRITICAL);
      expect(DefectClassifier.classify(page).severity).assertEqual(DefectSeverity.MAJOR);
      expect(DefectClassifier.classify(theme).severity).assertEqual(DefectSeverity.MINOR);
    });
  });
}
