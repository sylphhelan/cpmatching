# 使用官方 Flutter 稳定版镜像作为构建环境
FROM ghcr.io/cirruslabs/flutter:stable AS build

# 设置工作目录
WORKDIR /app

# 复制项目文件
COPY . .

# 获取项目依赖
RUN flutter pub get

# 构建 Web 版本
RUN flutter build web --release

# 使用轻量级 Nginx 镜像来提供构建产物
FROM nginx:alpine

# 将 Flutter 构建的 Web 文件复制到 Nginx 的默认服务目录
COPY --from=build /app/build/web /usr/share/nginx/html

# 暴露 80 端口
EXPOSE 80
