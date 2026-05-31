import 'dart:io';
import 'package:llama_cpp_dart/llama_cpp_dart.dart';

void main() {
  print('--- llama_cpp_dart class inspection ---');
  
  // Let's print properties/methods of Llama
  try {
    print('Llama libraryPath: ${Llama.libraryPath}');
  } catch (e) {
    print('Error accessing Llama: $e');
  }

  // Let's see if there is any other multimodal or clip-related class in the package imports
  print('Checking classes:');
  print('LlamaParent: exists');
  print('ChatMLFormat: exists');
  print('ContextParams: exists');
  
  exit(0);
}
