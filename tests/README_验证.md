# 修复验证说明

所有脚本只处理本地文件，不下载开发板。

## 快速媒体回归

`python tests/run_named_warning.py`

检查数字素材与 warning 槽位隔离、FAT 异常、SW1 进入/退出、音乐位置恢复、载入不同阶段被紧急请求打断、当前图片比例重绘以及重绘不重启音乐。使用小尺寸画面加快状态机验证。

`python tests/run_720.py packing_720 layer_720 warning_render timing_720`

检查无损 RGB24 打包/解包、整帧像素、独立图层位置与透明度、30 帧亮/30 帧灭，以及完整 1650×750 时序中的 1280×720 有效区。

`python tests/run_boot_top.py`

检查实际顶层中的自动开播、菜单持续播放、紧急缓冲切换、按键锁定与恢复。此用例在测试平台中缩短垂直有效区以加快控制验证；实际 720 行几何由 `timing_720` 单独检查。它不代替真实 HDMI 接收端测试。

## 真实 SDRAM 控制器回归

`python tests/run_modelsim_checks.py controller`

需要本机 TD 与 ModelSim，路径可用 `--td` 和 `--modelsim` 指定。脚本从工程导出 TD 映射后的控制器网表，加载官方原语模型和实际 FIFO RTL。外部 SDRAM 颗粒采用 `tests/sdram/sdram_model.sv` 的 BL4／CL3 功能模型。

最终用例检查 16 行原生 RGB24 连续读取、并发 3840 字写入、上下翻转地址、真实控制器忙信号、刷新和最终物理存储内容。初始化只跳过上电等待计数，保留初始化命令。此前 48 行、23040 字并发写入的日志也一并保留；最终 9 字节解包器以 16 行测试重新检查。

`build/controller_sim/baseline_reproduction.log` 记录旧调度在第 64 字开始写入高阻的失败。`frame_controller.log` 是最终修复后的结果。不能只用立即接受请求的理想内存模型证明真实控制器工作正常。

## 完整报警文件集成

先执行 `python tests/test_overlay_720.py` 生成测试输入，再执行：

`python tests/run_modelsim_checks.py native_warning`

此项仿真较慢，测试完整 3.686MB 的 1280×720 打包 warning BMP，真实 FAT、SD 扇区跨时钟接口、BMP/WAV 解析、FIFO 写入完成、呈现握手、匹配音频与精确续播。TF 介质和 SDRAM 应用接口由测试平台建模；真实 SDRAM 引脚控制的正确性由前一项独立验证。

## 交付校验

`python tests/check_font_netlist.py`、`python tests/check_phrase_netlist.py`、`python tests/check_control_netlist.py` 检查综合网表中的字库、菜单短语与控制寄存器。

`python tests/verify_release.py` 核对此次交付的最终时序、BIT、项目引用与实际回归记录，并生成文件哈希清单。当前发行使用 gate 综合日志加 seed 3 布线日志，两阶段生成同一份 BIT。继承的未修改模块历史测试会单独标记，不能当作本次新跑的测试。重新编译后，需要重新完成相关检查并更新构建审计记录，不能用旧记录直接认可新 BIT。

这些检查不包含板卡电源、SDRAM 电气时序实测、TF 卡兼容性和 HDMI 显示器实物测试。
