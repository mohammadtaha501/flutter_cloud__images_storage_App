
import 'dart:async';
import 'package:flutter/material.dart';

typedef CloseLoadingScreen=bool Function();
typedef UpdateLoadingScreen=bool Function(String text);

@immutable
class LoadingScreenController{
  final CloseLoadingScreen close;
  final UpdateLoadingScreen update;

  const LoadingScreenController({
    required this.close,
    required this.update
  }
      );
}
/// use of the LodingScreenController is to check weather the overlay is been displayed or not
class LoadngScreen{

  LoadngScreen._sharedinstance();
  static final _shared=LoadngScreen._sharedinstance();
  factory LoadngScreen()=>_shared;

  LoadingScreenController? _controller;

  void show({required BuildContext context,required String text}){
    ///if the _controller is null that overlay has not been show so it will return the false
    ///so the else will be executed which will show the overlay if the _controller has an object
    ///then it will update the text of the overlay and .update returns the true so after that function will return
    if(_controller?.update(text)??false){
      return;
    }else{
      _controller=_showOverlay(context: context, text: text);
    }
  }

  void close(){
    _controller?.close();
    _controller=null;
  }

  LoadingScreenController _showOverlay({required BuildContext context,required String text}){
    final text0= StreamController<String>();
    //get the size
    text0.add(text);
    final state=Overlay.of(context);
    final renderBox= context.findRenderObject() as RenderBox;
    final size = renderBox.size;

    final overlay = OverlayEntry(
      builder: (context) {
        return Material(
            color:Colors.black.withAlpha(150),
            child:Center(
              child: Container(
                constraints: BoxConstraints(
                  maxWidth: size.width* 0.8,
                  maxHeight: size.height* 0.8,
                  minWidth: size.width* 0.5,
                ),
                decoration: BoxDecoration(
                  color:Colors.white,
                  borderRadius: BorderRadius.circular(10.0),
                ),
                child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child:SingleChildScrollView(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const SizedBox(height: 10,),
                          const CircularProgressIndicator(),
                          const SizedBox(height: 20,),
                          StreamBuilder(
                            stream: text0.stream,
                            builder: (context, snapshot) {
                              if(snapshot.hasData){
                                return Text(
                                  snapshot.data!,
                                  textAlign: TextAlign.center,
                                );
                              }else{
                                return Container();
                              }
                            },)
                        ],
                      ),
                    )
                ),
              ),
            )
        );
      },
    );
    state.insert(overlay);
    return LoadingScreenController(close:() {
      text0.close();
      overlay.remove();
      return true;
    },
      update: (text) {
        text0.add(text);
        return true;
      },
    );

  }

}
