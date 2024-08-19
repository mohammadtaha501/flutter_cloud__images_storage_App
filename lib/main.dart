import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'generic_message.dart' show showGenericDialog;
import 'loading_screen.dart';

const Map<String,AuthError> authErrorMaping={
  'user-not-found':AuthErrorUserNOtFound(),
  'weak-password':AuthErrorWeakPassword(),
  'invalid-email':AuthErrorInvalidEmail(),
  'operation-not-allowed':AuthErrorOperationNotAllowed(),
  'email-already-exists':AuthErrorEmailAlreadyInUSe(),
  'email-already-in-use':AuthErrorEmailAlreadyInUSe(),
  'requires-recent-login':AuthErrorRequiresRecentLogin(),
  'no-current-user':AuthErrorNoCurrentUser(),
};
@immutable
abstract class AuthError{
  final String dialogTittle;
  final String dialogText;

  const AuthError({
    required this.dialogTittle,
    required this.dialogText,
  });

  factory AuthError.from(FirebaseAuthException exception)=>authErrorMaping[exception.code.toLowerCase().trim()]?? const AuthErrorUnknown();

}

@immutable
class AuthErrorUnknown extends AuthError{
  const AuthErrorUnknown():super(
      dialogText: 'An Unknown Error Occurred',
      dialogTittle: 'Authentication Error');

}

@immutable
class AuthErrorNoCurrentUser extends AuthError{
  const AuthErrorNoCurrentUser():super(
      dialogTittle:'No current user',
      dialogText:'No user with this information was found'
  );

}

@immutable
class AuthErrorRequiresRecentLogin extends AuthError{
  const AuthErrorRequiresRecentLogin():super(
    dialogTittle:'Requires Recent Login',
    dialogText:'you need to login out and login again in order to perform this operation',
  );

}
//if email sign method from the firebase is not enabled then user will get this error or if u r using the sign-in method u haven't enabled
@immutable
class AuthErrorOperationNotAllowed extends AuthError{
  const AuthErrorOperationNotAllowed():super(
      dialogTittle:'Operation Not Allowed',
      dialogText:"you can't register using this method at this moment"
  );
}

@immutable
class AuthErrorUserNOtFound extends AuthError{
  const AuthErrorUserNOtFound():super(
      dialogTittle:'user not found',
      dialogText:"the given credentials of the user was not found on the service"
  );
}

@immutable
class AuthErrorWeakPassword extends AuthError{
  const AuthErrorWeakPassword():super(
      dialogTittle:'weak password',
      dialogText:"please chose a stronger Password consisting of more characters"
  );
}

@immutable
class AuthErrorInvalidEmail extends AuthError{
  const AuthErrorInvalidEmail():super(
      dialogTittle:'Invalid Email',
      dialogText:"please please double check your email and try again"
  );
}

@immutable
class AuthErrorEmailAlreadyInUSe extends AuthError{
  const AuthErrorEmailAlreadyInUSe():super(
      dialogTittle:'Email already in use',
      dialogText:"please please chose another email and try again"
  );
}

@immutable
abstract class appEvent{
  const appEvent();
}

@immutable
class AppEventUploadImage implements appEvent{
  final String filePathToUpload;

  const AppEventUploadImage({
    required this.filePathToUpload,
  });
}

@immutable
class AppEventDeleteAccount implements appEvent{
  const AppEventDeleteAccount();
}

@immutable
class AppEventLogOut implements appEvent{
  const AppEventLogOut();
}

@immutable
class AppEventInitialized implements appEvent{
  const AppEventInitialized();
}

@immutable
class AppEventLogIn implements appEvent{
  final String email;
  final String password;

  const AppEventLogIn({
    required this.email,
    required this.password});
}

@immutable
class AppEventGoToRegistration implements appEvent{
  const AppEventGoToRegistration();
}

@immutable
class AppEventGoToLogIn implements appEvent{
  const AppEventGoToLogIn();
}

@immutable
class AppEventRegister implements appEvent{
  final String email;
  final String password;

  const AppEventRegister({
    required this.email,
    required this.password});
}

@immutable
abstract class appState{
  final bool isloading;
  final AuthError? authError;

  appState({
    required this.isloading,
    this.authError,
  });

}

@immutable
class AppStateLoggedIn extends appState {
  final User user;
  final Iterable<Reference> images;

  AppStateLoggedIn({
    required this.user,
    required this.images,
    required bool isLoading,
    AuthError? authError,
  }) :super( isloading: isLoading);

  @override
  bool operator ==(other) {
    final otherClass = other;
    if (otherClass is AppStateLoggedIn) {
//the isloading function is the object on which operator is called and otherClass.isloading is of the object which is on the right side when operator is used
      return isloading == otherClass.isloading &&
          user.uid == otherClass.user.uid &&
          images.length == otherClass.images.length;
    } else {
      return false;
    }
  }

  @override
  int get hashCode => Object.hash(
    user.uid,
    images,
  );

  @override
  String toString() => 'AppStateLogIn, images.length = ${images.length}';
}

@immutable
class AppStateLoggedOut extends appState{
  AppStateLoggedOut({
    required bool isLoading,
    AuthError? authError,
  }):super(authError: authError,isloading: isLoading);

  @override
  String toString() => 'AppStateLoggedOut, isLoading: $isloading, AuthError:$authError';
}

@immutable
class AppStateIsInRegisterView extends appState{

  AppStateIsInRegisterView({
    required bool isloading,
    AuthError? authError,
  }):super(isloading: isloading,authError: authError);

}

extension GetUser on appState{
  User? get user{
    final cls=this;
    if(cls is AppStateLoggedIn){
      return cls.user;
    }else{
      return null;
    }
  }
}

extension GetImages on appState{
  Iterable<Reference>? get images{
    final cls=this;
    if(cls is AppStateLoggedIn){
      return cls.images;
    }else{
      return null;
    }
  }
}

Future<bool> uploadImage(File file,String userId)
=> FirebaseStorage
    .instance
    .ref(userId)
    .child(const Uuid().v4())
    .putFile(file)
    .then((_) => true)
    .catchError((_)=>false);

class appBloc extends Bloc<appEvent,appState>{
  appBloc():super(
    AppStateLoggedOut(
        isLoading: false
    ),
  ){
    on<AppEventGoToRegistration>((event, emit) {
      emit(
          AppStateIsInRegisterView(isloading: false)
      );
    }
    );
    //handling the event when user presses the login button in the login view
    on<AppEventLogIn>((event, emit) async {
      emit(AppStateLoggedOut(isLoading: true));
      try{
        final email = event.email;
        final password = event.password;
        final userCredential = await FirebaseAuth.instance.signInWithEmailAndPassword(email: email, password: password);
        final user = userCredential.user!;
        final images = await _getImages(user.uid);
        emit(AppStateLoggedIn(user: user, images: images, isLoading: false));
      }on FirebaseAuthException catch(e){
        emit(AppStateLoggedOut(isLoading: false,authError: AuthError.from(e)));
      }
    });
    //handling the event when user press go to the login in the register view
    on<AppEventGoToLogIn>((event, emit) {
      emit(
          AppStateLoggedOut(isLoading: false)
      );
    });
    //handling the registration state
    on<AppEventRegister>((event, emit) async {
      emit(AppStateIsInRegisterView(isloading: true));
      final email=event.email;
      final password=event.password;
      try{
        final credential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
            email: email,
            password: password);
        emit(AppStateLoggedIn(user: credential.user!, images: const [], isLoading: false));
      }on FirebaseAuthException catch(e){
        emit(AppStateIsInRegisterView (isloading: true,authError: AuthError.from(e)));
      }
    }
    );
    //handling the initial state
    on<AppEventInitialized>((event, emit) async {
      final user = FirebaseAuth.instance.currentUser;
      if(user == null){
        emit(
          AppStateLoggedOut(isLoading: false),
        );
        return ;
      }
      //if user is not null then it means it is loggedin
      final images = await _getImages(user.uid);
      emit(AppStateLoggedIn(user: user, images: images, isLoading: false));

    });
    //handle the logged out state
    //do remember dont set the on with the appstate it should be appevent
    on<AppEventLogOut>((event, emit)async{
      emit(
          AppStateLoggedOut(isLoading: true)
      );
      await FirebaseAuth.instance.signOut();
      emit(
        AppStateLoggedOut(isLoading: false),
      );
    });
    //handling the account deletion
    on<AppEventDeleteAccount>((event, emit) async{
      final user = FirebaseAuth.instance.currentUser;
      if(user == null){
        emit(
          AppStateLoggedOut(isLoading: false),
        );
        return ;
      }
      //if user is still logged in
      emit(
        AppStateLoggedIn(user: user, images: state.images ?? [], isLoading: true),
      );
      //delete the user folder
      try{

        final folder = await FirebaseStorage.instance.ref(user.uid).listAll();
        for(final item in folder.items){
          await item.delete().catchError((_) {});
        }

        await FirebaseStorage.instance.ref(user.uid).delete().catchError((_) {});

        await user.delete();
        await FirebaseAuth.instance.signOut();
        emit(
          AppStateLoggedOut(isLoading: false),
        );
      }on FirebaseAuthException catch(e){

        emit(
          AppStateLoggedIn(user: user, images: state.images ?? [], isLoading: true,authError: AuthError.from(e)),
        );

      }on FirebaseException{
        emit(
            AppStateLoggedOut(isLoading: false)
        );
      }
    }
    );
    //handle uploading images
    on<AppEventUploadImage>((event, emit)async{
      final user = state.user;
      if(user==null){
        emit(
            AppStateLoggedOut(
              isLoading: false,
            )
        );
        return;
      }
      emit(
          AppStateLoggedIn(user: user, images: state.images ?? [], isLoading: true)
      );
      //grabbing the file reference of the files
      final file = File(event.filePathToUpload);
      await uploadImage(file, user.uid);
      final images = await _getImages(user.uid);
      emit(
        AppStateLoggedIn(user: user, images: images, isLoading: false),
      );

    });
  }

  Future<Iterable<Reference>> _getImages(String userId)=>
      FirebaseStorage.instance
          .ref(userId)
          .list()
          .then((listResult) => listResult.items);
}
// Dialogs
Future<bool> showDeleteDialog(BuildContext context){
  return showGenericDialog<bool>(
      context: context,
      message: 'are you sure you want to delete your account this cant be undo once done',
      tittle: 'delete account ',
      optionBuilder: () => {
        'Cancel':false,
        'Delete Account':true,
      }
  ).then((value) => value??false);
}

Future<bool> showLogoutDialog(BuildContext context){
  return showGenericDialog<bool>(
    context:context,
    message: 'are you sure you want to Logout',
    tittle: 'Log out ',
    optionBuilder: () => {
      'Cancel':false,
      'Log Out':true,
    }, ).then((value) => value??false);
}

Future<void> showAuthError(BuildContext context,AuthError authError){
  return showGenericDialog<void>(
      context: context,
      message: authError.dialogText,
      tittle: authError.dialogTittle,
      optionBuilder: () => {
        'Ok':true,
      });
}

extension IfDebugging on String{
  String? get ifDebugging=> kDebugMode ?this :null;
}

class loginView extends HookWidget {
  const loginView({super.key});

  @override
  Widget build(BuildContext context) {
    final emailController=useTextEditingController(text:'taha@gmail.com'.ifDebugging );
    final passwordController=useTextEditingController(text:'1Goodboy'.ifDebugging );
    return Scaffold(appBar: AppBar(
      title: const Text('Log in '),
    ),
      body: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          children: [
            TextField(
              controller: emailController,
              keyboardType: TextInputType.emailAddress,
              keyboardAppearance: Brightness.dark,
              decoration: const InputDecoration(
                hintText: 'enter your Email here',
              ),
            ),
            TextField(
              controller: passwordController,
              obscureText: true,
              decoration: const InputDecoration(
                hintText: 'enter your Password here',
              ),
            ),
            TextButton(onPressed: () {
              final email=emailController.text;
              final password=passwordController.text;
              context.read<appBloc>().add(
                  AppEventLogIn(
                      email: email, password: password)
              );
            },
                child: const Text('Log in')
            ),
            TextButton(onPressed: () {
              context.read<appBloc>().add(const AppEventGoToRegistration());
            },
                child: const Text('not registered yet?REGISTER HERE')
            ),
          ],
        ),
      ),
    );
  }
}

class registerView extends HookWidget {
  const registerView({super.key});

  @override
  Widget build(BuildContext context) {
    final emailController=useTextEditingController(text:'taha@gmail.com'.ifDebugging );
    final passwordController=useTextEditingController(text:'1Goodboy'.ifDebugging );
    return Scaffold(appBar: AppBar(
      title: const Text('Register'),
    ),
      body: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          children: [
            TextField(
              controller: emailController,
              keyboardType: TextInputType.emailAddress,
              keyboardAppearance: Brightness.dark,
              decoration: const InputDecoration(
                hintText: 'enter your Email here',
              ),
            ),
            TextField(
              controller: passwordController,
              obscureText: true,
              decoration: const InputDecoration(
                hintText: 'enter your Password here',
              ),
            ),
            TextButton(onPressed: () {
              final email=emailController.text;
              final password=passwordController.text;
              context.read<appBloc>().add(
                  AppEventRegister(
                      email: email, password: password)
              );
            },
                child: const Text('Register')
            ),
            TextButton(onPressed: () {
              context.read<appBloc>().add(const AppEventGoToLogIn());
            },
                child: const Text('already registered?LOGIN HERE')
            ),
          ],
        ),
      ),
    );
  }
}

enum MenuAction{logout,deleteAccount}

class MainPOpUpMenuButton extends StatelessWidget {
  const MainPOpUpMenuButton({super.key});

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton(
      color: Colors.white,
      itemBuilder: (context) {
        return [
          const PopupMenuItem(
            value:MenuAction.logout,
            child:Text("logout"),
          ),
          const PopupMenuItem(
            value:MenuAction.deleteAccount,
            child:Text("Delete Account"),
          )
        ];
      },
      onSelected:(value) async{
        switch (value){
          case MenuAction.logout:
            final shouldLogout= await showLogoutDialog(context);
            if(shouldLogout){
              context.read<appBloc>().add(AppEventLogOut());
            }
            break;
          case MenuAction.deleteAccount:
            final shouldDeleteAccount = await showDeleteDialog(context);
            if(shouldDeleteAccount){
              context.read<appBloc>().add(const AppEventDeleteAccount());
            }
            break;
        }
      },
    );
  }
}

class storageImageView extends StatelessWidget {
  final Reference image;
  const storageImageView({super.key,required this.image});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List?>(
        future: image.getData(),
        builder: (context, snapshot) {
          switch(snapshot.connectionState){

            case ConnectionState.none:

            case ConnectionState.waiting:

            case ConnectionState.active:
              return const Center(child: CircularProgressIndicator());
            case ConnectionState.done:
              if(snapshot.hasData){
                final data = snapshot.data!;
                return Image.memory(data,fit: BoxFit.cover,);
              }else{
                return const Center(child: CircularProgressIndicator());
              }

          }
        }
    );
  }
}

class PhotoGalleryView extends HookWidget {
  const PhotoGalleryView({super.key});

  @override
  Widget build(BuildContext context) {
    final _picker = useMemoized(() => ImagePicker(),[key]);

    Future<XFile?> _showPicker(BuildContext context) async {
      final ImagePicker _picker = ImagePicker();
      XFile? pickedFile;

      await showModalBottomSheet(
        context: context,
        builder: (BuildContext context) {
          return SafeArea(
            child: Wrap(
              children: <Widget>[
                ListTile(
                  leading: Icon(Icons.photo_library),
                  title: Text('Photo Library'),
                  onTap: () async {
                    pickedFile = await _picker.pickImage(source: ImageSource.gallery);
                    Navigator.of(context).pop();
                  },
                ),
                ListTile(
                  leading: Icon(Icons.camera_alt),
                  title: Text('Camera'),
                  onTap: () async {
                    pickedFile = await _picker.pickImage(source: ImageSource.camera);
                    Navigator.of(context).pop();
                  },
                ),
              ],
            ),
          );
        },
      );

      return pickedFile;
    }

    final images = context.watch<appBloc>().state.images ?? [];
    return Scaffold(
      appBar: AppBar(
        title: const Text('Photo Gallery'),
        actions: [
          IconButton(
            onPressed: () async{
              final image = await _showPicker(context);
              if(image==null){
                return;
              }else{
                context.read<appBloc>().add(
                    AppEventUploadImage(filePathToUpload: image.path)
                );
              }
            },
            icon: const Icon(Icons.upload),
          ),
          const MainPOpUpMenuButton(),
        ],
      ),
      body: GridView.count(
        crossAxisCount: 2,
        padding: const EdgeInsets.all(8),
        mainAxisSpacing: 20.0,
        crossAxisSpacing: 20.0,
        children: images.map((img) => storageImageView(image: img)).toList(),
      ),
    );
  }
}
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final loadingShow=LoadngScreen();
  runApp( BlocProvider<appBloc>(
    create: (_)=> appBloc()..add(
        const AppEventInitialized()
    ),
    child: MaterialApp(
      title: 'Image upload App',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: BlocConsumer<appBloc,appState>(
        listener: (context, appState) {
          if(appState.isloading){
            loadingShow.show(context: context, text: 'Loading...');
          }else{
            loadingShow.close();
          }
          final authError= appState.authError;
          if(authError != null){
            showAuthError(context, authError);
          }
        },
        builder: (context, appState) {
          if(appState is AppStateLoggedOut){
            return const loginView();
          }else if(appState is AppStateLoggedIn){
            return const PhotoGalleryView();
          }else if(appState is AppStateIsInRegisterView){
            return const registerView();
          }else{
            //this should never happens
            return Container();
          }
        },
      ),
    ),
  )
  );
}


