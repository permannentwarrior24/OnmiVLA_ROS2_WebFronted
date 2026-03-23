# car

flutter config --enable-web
flutter run -d web-server --web-hostname 0.0.0.0 --web-port 28080

基于 Flutter Web 的车端可视化控制台，用于连接 ROS2 节点
`/home/apollo/disk/ros2/src/car/car/recv_prompt.py` 暴露的 HTTP API。

## 功能

- 连接并检测节点健康状态：`GET /api/health`
- 周期拉取状态：`GET /api/state`
- 显示模型文本、图像帧（Base64 JPEG）和路径点列表
- 提交用户输入 prompt：`POST /api/prompt`

## 架构

工程采用 MVVM 分层：

- `lib/models`: 领域模型（`CarState`, `Waypoint`）
- `lib/services`: 接口访问层（`RecvPromptApiService`）
- `lib/viewmodels`: 状态管理与业务编排（`CarDashboardViewModel`）
- `lib/views`: 页面与 UI 组件（`CarDashboardPage`）

## 目录

```
lib/
	app.dart
	main.dart
	models/
		car_state.dart
	services/
		recv_prompt_api_service.dart
	viewmodels/
		car_dashboard_view_model.dart
	views/
		car_dashboard_page.dart
```

## 本地运行

1. 启动 ROS 节点（会内置启动 FastAPI）
2. 在本项目目录执行：

```bash
flutter pub get
flutter run -d chrome
```

默认会连接 `http://<当前页面主机>:8787`，也可在页面中手动修改 API 地址。

## 接口数据约定

`GET /api/state` 关键字段：

- `text`: `String`
- `frame_id`: `String`
- `image_jpeg_b64`: `String`（Base64 编码 JPEG）
- `waypoints`: `[{x: double, y: double, z: double}]`

`POST /api/prompt` 请求体：

```json
{
	"text": "your prompt"
}
```
