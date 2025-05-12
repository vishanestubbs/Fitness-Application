import SwiftUI
import Foundation
import FirebaseAuth
import Combine
import FirebaseFirestore
import FirebaseFirestoreCombineSwift

enum AuthenticationState {
case unauthenticated
case authenticating
case authenticated
case onboarding
}

enum AuthenticationFlow{
    case login
    case home
}

@MainActor
class AuthState: ObservableObject {
    @Published var fullname : String = ""
    @Published var email: String = ""
    @Published var password: String = ""
    @Published var confirmedpassword:String=""
    @Published var errormessage:String = ""
    @Published var flow: AuthenticationFlow = .login
    @Published var isValid: Bool = false
    @Published var auth_state: AuthenticationState = .unauthenticated
    @Published var user: FirebaseAuth.User?
    @Published var currentuser: User?
    @Published var workouts : [WorkoutItem]?
    
    init(){
        registerAuthStateHandler()
        $flow
            .combineLatest($email,$password,$confirmedpassword)
            .map{flow,email,password,confirmedpassword in
                flow == .login
                ? !(email.isEmpty || password.isEmpty)
                : !(email.isEmpty || password.isEmpty || confirmedpassword.isEmpty)
            }
            .assign(to: &$isValid)
        
    }
    private var authStateHandle: AuthStateDidChangeListenerHandle?
    func registerAuthStateHandler() {
        if authStateHandle == nil {
            authStateHandle = Auth.auth().addStateDidChangeListener { auth, user in
                self.user = user
                
                if user == nil {
                    self.auth_state = .unauthenticated
                    self.currentuser = nil
                    print("🚪 Signed out: unauthenticated.")
                } else {
                    print("👤 Authenticated Firebase user found. UID: \(user!.uid)")
                    Task {
                        await self.fetchUser()
                        await self.fetchWorkouts()
                    }
                }
            }
        }
    }
}


extension AuthState{
    func signInWithEmailandPassword()async -> Bool{
        auth_state = .authenticating
        do{
            let result = try await Auth.auth().signIn(withEmail: email, password: password)
            user = result.user
            print("User \(result.user.uid) signed in")
            await fetchUser()
            return true
        }
        catch{
            print(error)
            errormessage = error.localizedDescription
            return false
        }
        
    }
    
    func signUpwithEmailandPassword()async -> Bool{
        auth_state = .authenticating
        do{
            let result = try await Auth.auth().createUser(withEmail: email, password: password)
            user = result.user
            auth_state = .onboarding
            print("User \(result.user.uid) signed in")
            return true
        }
        catch{
            print(error)
            errormessage = error.localizedDescription
            return false
        }
        
    }
    
    func signOut()async -> Bool{
        do{
            try Auth.auth().signOut()
            return true
        }
        catch{
            print(error)
            return false
        }
    }
    
    func deleteAccount() async -> Bool{
        do{
            try await user?.delete()
            email=""
            password=""
            confirmedpassword=""
            return true
        }
        catch{
            print(error)
            return false
        }
    }
    
    func fetchUser() async {
        guard let uid = Auth.auth().currentUser?.uid else {
            print("❌ No current user UID")
            return
        }
        
        print("🔍 Fetching user with UID: \(uid)")
        
        do {
            let snapshot = try await Firestore.firestore()
                .collection("UserInputs")
                .document(uid)
                .getDocument()
            
            if snapshot.exists {
                self.currentuser = try snapshot.data(as: User.self)
                print("✅ User loaded: \(self.currentuser?.fullname ?? "Unknown")")
                self.auth_state = .authenticated
            } else {
                print("⚠️ No user document found — switching to onboarding.")
                self.auth_state = .onboarding
            }
        } catch {
            print("❌ Firestore fetch error: \(error.localizedDescription)")
            self.auth_state = .unauthenticated
        }
    }
    
    //fetching user documents
    func fetchWorkouts() async {
        guard let uid = Auth.auth().currentUser?.uid else {
            print("❌ No current user UID")
            return
        }
        print("🔍 Fetching user with UID: \(uid)")
        
        do {
            let workouts = try await Firestore.firestore().collection("UserInputs").document(uid).collection("workouts").getDocuments()
            
            if !workouts.isEmpty{
                let decodedWorkouts = try workouts.documents.compactMap {
                    try $0.data(as: WorkoutItem.self)
                }
                self.workouts = decodedWorkouts
                
                print("✅ Loaded \(decodedWorkouts.count) workouts")
            } else {
                
                print("⚠️ No workout document found")
                
            }
            
        }
        catch {
            print("❌ Firestore fetch error: \(error.localizedDescription)")
        }
        
        
        
        
    }
    
    func StoreWorkouts(workout:WorkoutItem)async {
       do {
           
           let encodedUser = try Firestore.Encoder().encode(workout)
           
           try await Firestore.firestore()
               .collection("UserInputs")
               .document(Auth.auth().currentUser?.uid ?? UUID().uuidString)
               .collection("workouts")
               .document(workout.id)
               .setData(encodedUser)
           print("✅ Workout stored ")

           
       } catch {
           print("🔥 Firestore save failed: \(error.localizedDescription)")
           self.errormessage = "Failed to save user data."
       }
   }
}


