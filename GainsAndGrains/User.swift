//
//  User.swift
//  GainsAndGrains
//
//  Created by Vishane Stubbs on 10/05/2025.
//
import Foundation
import SwiftUI

struct User: Identifiable,Codable{
    let id: String
    let fullname: String
    let age : Int
    let gender:String
    let height: Int
    let weight: Int
    let fitnessGoal : String
    let dietaryPreference: String
    let activityLevel: String
    let equipmentAccess : String
    let mealsPerDay: Int
    
    var initials:String{
        let formatter = PersonNameComponentsFormatter()
        if let components = formatter.personNameComponents(from: fullname){
            formatter.style = .abbreviated
            return formatter.string(from: components)
        }
        return "NA"
    }
}

extension User{
    static var MOCK_USER = User(id: NSUUID().uuidString, fullname: "Charles Leclerc", age: 27,gender: "Male",height: 50,weight: 100, fitnessGoal: "Strength",dietaryPreference: "None",activityLevel:"Sedentary",equipmentAccess: "None",mealsPerDay: 2)
}


struct WorkoutItem: Identifiable, Hashable,Codable{
    let id : String
    var title: String
    var description: [String]
    var likes: Int
    var duration: Int
    var category : String
}

extension WorkoutItem{
    static var MOCK_WORKOUT = WorkoutItem(id: UUID().uuidString, title: "Chest Day #1", description: ["Barbell Bench"], likes: 0, duration: 20, category: "Chest")
}



/*do {
    let user = User(
        id: authState.user?.uid ?? UUID().uuidString,
        fullname: authState.fullname,
        age: age,
        gender: gender,
        height: height,
        weight: weight,
        fitnessGoal: fitnessGoal,
        dietaryPreference: dietaryPreference,
        activityLevel: activityLevel,
        equipmentAccess: equipmentAccess,
        mealsPerDay: meals
    )
    
    let encodedUser = try Firestore.Encoder().encode(user)
    
    try await Firestore.firestore()
        .collection("UserInputs")
        .document(user.id)
        .setData(encodedUser)
    
     await authState.fetchUser()
} catch {
    print("🔥 Firestore save failed: \(error.localizedDescription)")
    authState.errormessage = "Failed to save user data."
}
}*/
