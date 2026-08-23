import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter_gpu/gpu.dart' as gpu;
import 'package:vector_math/vector_math.dart' as vm;

import 'shaders.dart';

typedef CubeRendererLoader = Future<CubeFrameRenderer> Function();

abstract interface class CubeFrameRenderer implements Listenable {
  void paintFrame(
    ui.Canvas canvas,
    ui.Size size, {
    required double devicePixelRatio,
    required double cubeSize,
    required double rotationX,
    required double rotationY,
  });

  void dispose();
}

final class CubeRenderer extends ChangeNotifier implements CubeFrameRenderer {
  CubeRenderer._(
    this._shaderController,
    this._vertexShader,
    this._fragmentShader,
  ) {
    _rebuildPipeline();

    final vertices = Float32List.fromList(_vertexData);
    _vertexBuffer = gpu.gpuContext.createDeviceBufferWithCopy(
      vertices.buffer.asByteData(),
    );
    _vertexView = gpu.BufferView(
      _vertexBuffer,
      offsetInBytes: 0,
      lengthInBytes: vertices.lengthInBytes,
    );

    final indices = Uint16List.fromList(_indexData);
    _indexBuffer = gpu.gpuContext.createDeviceBufferWithCopy(
      indices.buffer.asByteData(),
    );
    _indexView = gpu.BufferView(
      _indexBuffer,
      offsetInBytes: 0,
      lengthInBytes: indices.lengthInBytes,
    );

    _uniforms = gpu.gpuContext.createHostBuffer(blockLengthInBytes: 1024);
    _shaderController.startWatching(onReload: _handleShaderReload);
  }

  static Future<CubeRenderer> create() async {
    final controller = await CubeShaderController.load();
    final vertexShader = controller.library['CubeVertex'];
    final fragmentShader = controller.library['CubeFragment'];

    if (vertexShader == null || fragmentShader == null) {
      throw StateError('Cube shaders are missing from the shader bundle.');
    }
    return CubeRenderer._(controller, vertexShader, fragmentShader);
  }

  static const int _floatsPerVertex = 7;

  static const List<double> _vertexData = [
    // Front.
    -1, -1, 1, 1, 0.18, 0.28, 1,
    1, -1, 1, 1, 0.18, 0.28, 1,
    1, 1, 1, 1, 0.18, 0.28, 1,
    -1, 1, 1, 1, 0.18, 0.28, 1,
    // Back.
    1, -1, -1, 0.22, 0.94, 0.62, 1,
    -1, -1, -1, 0.22, 0.94, 0.62, 1,
    -1, 1, -1, 0.22, 0.94, 0.62, 1,
    1, 1, -1, 0.22, 0.94, 0.62, 1,
    // Top.
    -1, 1, 1, 0.43, 0.91, 1, 1,
    1, 1, 1, 0.43, 0.91, 1, 1,
    1, 1, -1, 0.43, 0.91, 1, 1,
    -1, 1, -1, 0.43, 0.91, 1, 1,
    // Bottom.
    -1, -1, -1, 1, 0.73, 0.22, 1,
    1, -1, -1, 1, 0.73, 0.22, 1,
    1, -1, 1, 1, 0.73, 0.22, 1,
    -1, -1, 1, 1, 0.73, 0.22, 1,
    // Right.
    1, -1, 1, 0.58, 0.36, 1, 1,
    1, -1, -1, 0.58, 0.36, 1, 1,
    1, 1, -1, 0.58, 0.36, 1, 1,
    1, 1, 1, 0.58, 0.36, 1, 1,
    // Left.
    -1, -1, -1, 1, 0.31, 0.76, 1,
    -1, -1, 1, 1, 0.31, 0.76, 1,
    -1, 1, 1, 1, 0.31, 0.76, 1,
    -1, 1, -1, 1, 0.31, 0.76, 1,
  ];

  static const List<int> _indexData = [
    0,
    1,
    2,
    0,
    2,
    3,
    4,
    5,
    6,
    4,
    6,
    7,
    8,
    9,
    10,
    8,
    10,
    11,
    12,
    13,
    14,
    12,
    14,
    15,
    16,
    17,
    18,
    16,
    18,
    19,
    20,
    21,
    22,
    20,
    22,
    23,
  ];

  final CubeShaderController _shaderController;
  final gpu.Shader _vertexShader;
  final gpu.Shader _fragmentShader;
  late gpu.RenderPipeline _pipeline;
  late final gpu.DeviceBuffer _vertexBuffer;
  late final gpu.DeviceBuffer _indexBuffer;
  late final gpu.BufferView _vertexView;
  late final gpu.BufferView _indexView;
  late final gpu.HostBuffer _uniforms;
  late gpu.UniformSlot _frameInfoSlot;

  void _rebuildPipeline() {
    _pipeline = gpu.gpuContext.createRenderPipeline(
      _vertexShader,
      _fragmentShader,
      vertexLayout: const gpu.VertexLayout(
        buffers: [
          gpu.VertexBuffer(
            strideInBytes: _floatsPerVertex * Float32List.bytesPerElement,
            attributes: [
              gpu.VertexAttribute(
                name: 'position',
                format: gpu.VertexFormat.float32x3,
              ),
              gpu.VertexAttribute(
                name: 'color',
                format: gpu.VertexFormat.float32x4,
                offsetInBytes: 3 * Float32List.bytesPerElement,
              ),
            ],
          ),
        ],
      ),
    );
    _frameInfoSlot = _vertexShader.getUniformSlot('FrameInfo');
  }

  void _handleShaderReload() {
    _rebuildPipeline();
    notifyListeners();
  }

  @override
  void paintFrame(
    ui.Canvas canvas,
    ui.Size size, {
    required double devicePixelRatio,
    required double cubeSize,
    required double rotationX,
    required double rotationY,
  }) {
    if (size.isEmpty) {
      return;
    }

    final width = math.max(1, (size.width * devicePixelRatio).round());
    final height = math.max(1, (size.height * devicePixelRatio).round());
    final colorTexture = gpu.gpuContext.createTexture(
      gpu.StorageMode.devicePrivate,
      width,
      height,
      enableRenderTargetUsage: true,
      enableShaderReadUsage: true,
    );
    final depthTexture = gpu.gpuContext.createTexture(
      gpu.StorageMode.deviceTransient,
      width,
      height,
      format: gpu.gpuContext.defaultDepthStencilFormat,
      enableRenderTargetUsage: true,
      enableShaderReadUsage: false,
    );
    final renderTarget = gpu.RenderTarget.singleColor(
      gpu.ColorAttachment(
        texture: colorTexture,
        clearValue: vm.Vector4(0.025, 0.035, 0.065, 1),
      ),
      depthStencilAttachment: gpu.DepthStencilAttachment(
        texture: depthTexture,
        depthClearValue: 1,
      ),
    );

    final commandBuffer = gpu.gpuContext.createCommandBuffer();
    final renderPass = commandBuffer.createRenderPass(renderTarget);
    renderPass.bindPipeline(_pipeline);
    renderPass.setViewport(gpu.Viewport(width: width, height: height));
    renderPass.setDepthWriteEnable(true);
    renderPass.setDepthCompareOperation(gpu.CompareFunction.less);
    renderPass.bindVertexBuffer(_vertexView);
    renderPass.bindIndexBuffer(_indexView, gpu.IndexType.int16);

    _uniforms.reset();
    final uniformView = _uniforms.emplace(
      _createMvpMatrix(
        width: width,
        height: height,
        cubeSize: cubeSize,
        rotationX: rotationX,
        rotationY: rotationY,
      ).buffer.asByteData(),
    );
    renderPass.bindUniform(_frameInfoSlot, uniformView);
    renderPass.drawIndexed(_indexData.length);
    commandBuffer.submit();

    final image = colorTexture.asImage();
    canvas.drawImageRect(
      image,
      ui.Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      ui.Offset.zero & size,
      ui.Paint()..filterQuality = ui.FilterQuality.high,
    );
    image.dispose();
  }

  Float32List _createMvpMatrix({
    required int width,
    required int height,
    required double cubeSize,
    required double rotationX,
    required double rotationY,
  }) {
    final model = vm.Matrix4.identity()
      ..rotateX(rotationX)
      ..rotateY(rotationY)
      ..scaleByDouble(cubeSize, cubeSize, cubeSize, 1);
    final view = vm.Matrix4.translationValues(0, 0, -5);
    final projection = vm.makePerspectiveMatrix(
      46 * math.pi / 180,
      width / height,
      0.1,
      100,
    );
    final mvp = projection * view * model;
    return Float32List.fromList(mvp.storage);
  }

  @override
  void dispose() {
    unawaited(_shaderController.dispose());
    super.dispose();
  }
}
