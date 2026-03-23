/**
 * echarts-for-react 的测试 Mock，避免 jsdom 环境中 Canvas API 缺失导致报错。
 */
const ReactECharts = () => <div data-testid="echarts-mock" />;
export default ReactECharts;
