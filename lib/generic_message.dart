import 'package:flutter/material.dart';

typedef DialogOptionBuilder<T>=Map<String,dynamic> Function();

Future<T?> showGenericDialog<T>({required BuildContext context,required String message,required String tittle ,required DialogOptionBuilder optionBuilder}){
  final options = optionBuilder();
  return showDialog<T?>(context: context, builder:(context){
    return AlertDialog(
      title: Text(tittle),
      content: Text(message),
      actions: options.keys.map((optionTitle){
        final value =options[optionTitle];
        return TextButton(onPressed: () {
          if(value!=null){
            Navigator.of(context).pop(value);
          }else{
            Navigator.of(context).pop();
          }
        }, child: Text(optionTitle));

      }).toList(),
    );
  }
  );
}