
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:google_ml_kit/google_ml_kit.dart';


List<CameraDescription> cameras;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  cameras = await availableCameras();
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  MyHomePage({Key key, this.title}) : super(key: key);
  final String title;
  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  CameraController controller;
  bool isBusy = false;
  FaceDetector detector;
  Size size;
  List<Face> faces;
  CameraDescription description;
  CameraLensDirection camDirec = CameraLensDirection.front;
  @override
  void initState() {
    super.initState();
    initializeCamera();
  }

  //TODO code to initialize the camera feed
  initializeCamera() async {

    controller = CameraController(description, ResolutionPreset.medium);
    detector = GoogleMlKit.vision.faceDetector();
    await controller.initialize().then((_) {
      if (!mounted) {
        return;
      }
      controller.startImageStream((image) => {
            if (!isBusy) {
              isBusy = true,
              doFaceDetectionOnFrame(image)}
          });
    });
  }

  //close all resources
  @override
  void dispose() {
    controller?.dispose();
    detector.close();
    super.dispose();
  }

  //TODO face detection on a frame
  dynamic _scanResults;
  doFaceDetectionOnFrame(CameraImage img) async {
    var frameImg = getInputImage(img);
    List<Face> faces = await detector.processImage(frameImg);
    setState(() {
      _scanResults = faces;
    });
    isBusy = false;
  }

  InputImage getInputImage(CameraImage image){

    final WriteBuffer allBytes = WriteBuffer();
    for (Plane plane in image.planes) {
      allBytes.putUint8List(plane.bytes);
    }
    final bytes = allBytes.done().buffer.asUint8List();

    final Size imageSize = Size(image.width.toDouble(), image.height.toDouble());

    final InputImageRotation imageRotation =
        InputImageRotationMethods.fromRawValue(cameras[0].sensorOrientation) ??
            InputImageRotation.Rotation_0deg;

    final InputImageFormat inputImageFormat =
        InputImageFormatMethods.fromRawValue(image.format.raw) ??
            InputImageFormat.NV21;

    final planeData = image.planes.map(
          (Plane plane) {
        return InputImagePlaneMetadata(
          bytesPerRow: plane.bytesPerRow,
          height: plane.height,
          width: plane.width,
        );
      },
    ).toList();

    final inputImageData = InputImageData(
      size: imageSize,
      imageRotation: imageRotation,
      inputImageFormat: inputImageFormat,
      planeData: planeData,
    );

    final inputImage = InputImage.fromBytes(bytes: bytes, inputImageData: inputImageData);
    return inputImage;
  }

  //Show rectangles around detected faces
  Widget buildResult(){
    if (_scanResults == null ||
        controller == null ||
        !controller.value.isInitialized) {
      return Text('');
    }

    final Size imageSize = Size(
      controller.value.previewSize.height,
      controller.value.previewSize.width,

    );
    CustomPainter painter = FaceDetectorPainter(imageSize, _scanResults,camDirec);
    return CustomPaint(
      painter: painter,
    );

  }

  //toggle camera direction
  void _toggleCameraDirection() async {
    if (camDirec == CameraLensDirection.back) {
      camDirec = CameraLensDirection.front;
    } else {
      camDirec = CameraLensDirection.back;
    }

    await controller.stopImageStream();
    await controller.dispose();

    setState(() {
      controller = null;
    });

    initializeCamera();
  }
  
  @override
  Widget build(BuildContext context) {
    List<Widget> stackChildren = [];
    size = MediaQuery.of(context).size;
    if(controller != null) {
      stackChildren.add(
        Positioned(
          top: 0.0,
          left: 0.0,
          width: size.width,
          height: size.height - 250,
          child: Container(
            child: (controller.value.isInitialized)
                ? AspectRatio(
              aspectRatio: controller.value.aspectRatio,
              child: CameraPreview(controller),
            )
                : Container(),
          ),
        ),
      );

      stackChildren.add(Positioned(
        top: 0.0,
        left: 0.0,
        width: size.width,
        height: size.height - 250,
        child: buildResult()
      ),);
    }

      stackChildren.add(Positioned(
        top: size.height - 250,
        left: 0,
        width: size.width,
        height: 250,
        child: Container(
          child: Center(
            child: Container(
              margin: EdgeInsets.only(bottom: 80),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                    IconButton(
                      icon: Icon(Icons.cached,color: Colors.white,),
                      iconSize: 50,
                      color: Colors.black,
                      onPressed: (){
                        _toggleCameraDirection();
                      },
                    )
                  ],),
                ],
              ),
            ),
          ),
          color: Colors.grey,
        ),
      ));


    return Scaffold(
      appBar: AppBar(title: Text("Face detector"),backgroundColor: Colors.grey,),
      backgroundColor: Colors.black,
      body: Container(
          margin: EdgeInsets.only(top: 0),
          color: Colors.black,
          child: Stack(
            children: stackChildren,
          )),
    );
  }
}

class FaceDetectorPainter extends CustomPainter {
  FaceDetectorPainter(this.absoluteImageSize, this.faces,this.camDire2);

  final Size absoluteImageSize;
  final List<Face> faces;
  CameraLensDirection camDire2;

  @override
  void paint(Canvas canvas, Size size) {
    final double scaleX = size.width / absoluteImageSize.width;
    final double scaleY = size.height / absoluteImageSize.height;

    final Paint paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..color = Colors.red;

    for (Face face in faces) {
      canvas.drawRect(
        Rect.fromLTRB(
          camDire2 == CameraLensDirection.front?(absoluteImageSize.width-face.boundingBox.right) * scaleX:face.boundingBox.left * scaleX,
          face.boundingBox.top * scaleY,
          camDire2 == CameraLensDirection.front?(absoluteImageSize.width-face.boundingBox.left) * scaleX:face.boundingBox.right * scaleX,
          face.boundingBox.bottom * scaleY,
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(FaceDetectorPainter oldDelegate) {
    return oldDelegate.absoluteImageSize != absoluteImageSize ||
        oldDelegate.faces != faces;
  }
}
