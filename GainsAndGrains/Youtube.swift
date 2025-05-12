import SwiftUI
import UIKit
import CoreML
import FirebaseFirestore


extension MLMultiArray {
    func topKIndices(_ k: Int) -> [Int] {
        let pairs: [(Int, Double)] = (0..<self.count).map { ($0, self[$0].doubleValue) }
        let sorted = pairs.sorted { $0.1 > $1.1 }
        return Array(sorted.prefix(k).map { $0.0 })
    }
}


struct Youtube: View {
    let categories = ["Chest", "Biceps", "Quadriceps", "Lats"]

    @EnvironmentObject private var authState: AuthState
    @State var level: String = "Intermediate"
    @State var rating: Double = 8
    @State var model = try! Workouts(configuration: MLModelConfiguration())
    @State var pre = Preprocessor.shared
    @State var bodyParts = ["Chest", "Quadriceps", "Shoulder", "Biceps"]
    @State private var recommendations: [String: [String]] = [:]
    @State private var popularItems: [WorkoutItem] = [
        WorkoutItem(id: UUID().uuidString,title: "Title 1", description: ["Description"], likes: 353, duration:17,category:"Chest"),
        WorkoutItem(id: UUID().uuidString,title: "Title 2", description: ["Description"], likes: 26, duration: 44,category:"Back")
    ]
    
    @State var filteredworkouts: [WorkoutItem] = []
    
    //filter popular content
    func filterPopularItems(by category: String?) {
        withAnimation(.easeInOut) {
            if let category = category {
                popularItems = filteredworkouts.filter { $0.category == category }
            } else {
                popularItems = filteredworkouts
            }
        }
    }

    private func computeRecommendations(for user: User) {
        var newRecs: [String: [String]] = [:]
        for part in bodyParts {
            do {
                let mlArr = try pre.makeInputArray(
                    type: user.fitnessGoal,
                    bodyPart: part,
                    equipment: user.equipmentAccess,
                    level: level,
                    rating: rating
                )
                let input = WorkoutsInput(dense_input: mlArr)
                let output = try model.prediction(input: input)
                let probs = output.Identity
                let top2 = probs.topKIndices(3)
                let suggestions = top2.map { pre.titles[$0] }
                newRecs[part] = suggestions
            } catch {
                newRecs[part] = ["—", "—", "—"]
            }
        }
        recommendations = newRecs
    }
    
     
    

    var body: some View {
        if let user = authState.currentuser {
            NavigationView {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        WelcomeSection()
                        RecommendationSection(bodyParts: bodyParts, recommendations: recommendations)
                        CategorySection(categories: categories,SelectCategory: {category in filterPopularItems(by: category)
                        })
                        PopularSection(popularItems: $popularItems, SeeAll:{category in filterPopularItems(by: category)
                        })
                    }
                    .padding(.top)
                    
                }.padding(.top)
                
                .navigationBarHidden(true)
            }
            .onAppear {
                    Task {
                        await authState.fetchWorkouts()
                        
                        if let stored = authState.workouts {
                                    let newOnes = stored.filter { storedWorkout in
                                        !popularItems.contains(where: { $0.id == storedWorkout.id })
                                    }
                                popularItems.insert(contentsOf: newOnes, at: 0)
                            filteredworkouts = popularItems
                                }

                    }
                
                computeRecommendations(for: user)
            }
        } else {
            ProgressView("Loading your dashboard...")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.black.ignoresSafeArea())
        }
    }
}

struct WelcomeSection: View {
    @EnvironmentObject private var authState: AuthState
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Spacer(minLength: 20)
            Text("Welcome")
                .font(.largeTitle)
                .bold()
                .padding(.horizontal)

            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.gray)
                Text("Search")
                    .foregroundColor(.gray)
                Spacer()
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
            .padding(.horizontal)
        }
    }
}

struct RecommendationSection: View {
    @EnvironmentObject private var authState: AuthState
    let bodyParts: [String]
    let recommendations: [String: [String]]

    var body: some View {
        VStack(alignment: .leading) {
            Text("Recommendations")
                .font(.title2)
                .bold()
                .padding(.horizontal)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(bodyParts, id: \.self) { item in
                        NavigationLink(destination: DetailView(title: item)) {
                            RecommendationCard(title: item, exercises: recommendations[item] ?? [])
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
    }
}

struct RecommendationCard: View {
    @EnvironmentObject private var authState: AuthState
    let title: String
    let exercises: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Rectangle()
                .fill(LinearGradient(
                    gradient: Gradient(colors: [Color.blue, Color.purple]),
                    startPoint: .leading,
                    endPoint: .trailing))
                .frame(width: 50, height: 5)
                .cornerRadius(2.5)

            Text(title)
                .font(.headline)
                .foregroundColor(.white)
                .lineLimit(1)
                .truncationMode(.tail)

            Divider().background(Color.gray)

            ForEach(0..<min(exercises.count, 3), id: \.self) { i in
                Text(exercises[i])
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
        }
        .padding()
        .frame(width: 250)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.sRGB, white: 0.15, opacity: 1))
                .shadow(color: Color.blue.opacity(0.2), radius: 10, x: 0, y: 5)
        )
    }
}

struct CategorySection: View {
    @EnvironmentObject private var authState: AuthState
    let categories: [String]
    let SelectCategory: (String?) -> Void
    //@State private var selected: String? = nil
    
    
    var body: some View {
        VStack(alignment: .leading) {
            Text("Categories")
                .font(.title2)
                .bold()
                .padding(.horizontal)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(categories, id: \.self) { category in
                        Text(category)
                            .font(.subheadline)
                            .padding(.vertical, 6)
                            .padding(.horizontal, 12)
                            .background(Color.purple.opacity(0.2))
                            .cornerRadius(16)
                            .onTapGesture {SelectCategory(category)}
                            }
                    }
                }
                .padding(.horizontal)
            }
        }
    }


struct PopularSection: View {
    @EnvironmentObject private var authState: AuthState
    @Binding var popularItems: [WorkoutItem]
    let SeeAll: (String?) -> Void

    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Text("Popular Content")
                    .font(.title2)
                    .bold()
                Spacer()
                Text("See All")
                    .foregroundColor(.purple)
                    .font(.subheadline)
                    .onTapGesture {SeeAll(nil)}
            }
            .padding(.horizontal)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                ForEach($popularItems) { $item in
                    NavigationLink(destination: CreateWorkout(item: $item)) {
                        PopularCard(item: $item)
                        
                    }
                }
            }
            .padding(.horizontal)
        }
        
    }
}

struct PopularCard: View {
    @EnvironmentObject private var authState: AuthState
    @Binding var item: WorkoutItem
    

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Rectangle()
                .fill(Color.yellow)
                .frame(height: 75)
                .cornerRadius(12)

            Text(item.title)
                .font(.headline)

            ForEach(item.description, id: \.self){ ex in
                Text(ex)
                    .font(.caption)
                    .foregroundColor(.gray)
                    .lineLimit(1)
                    .truncationMode(.tail)
              
                
            }
            

            HStack {
                Label("\(item.likes)", systemImage: "heart")
                    .font(.caption)
                Spacer()
                Text("\(item.duration) min")
                    .font(.caption)
            }
            .foregroundColor(.gray)
        }
        .padding()
        .frame(height: 250)
        .background(Color(.systemGray6))
        .cornerRadius(16)
    }
}

struct DetailView: View {
    @EnvironmentObject private var authState: AuthState
    let title: String

    var body: some View {
        VStack {
            Text("Details for \(title)")
                .font(.largeTitle)
                .padding()
            Spacer()
        }
        .navigationTitle(title)
    }
}

struct CreateWorkout: View {
    @EnvironmentObject private var authState: AuthState
    @Binding var item: WorkoutItem
    @State private var showPicker = false
    @State private var selectedExercise = "Barbell Squat"
    @State private var pre = Preprocessor.shared

    var body: some View {
        Form {
            Section(header: Text("Workout Info")) {
                TextField("Title", text: $item.title)
                    
            }
            
            Section(header: Text("Category")) {
                Picker("Category", selection: $item.category) {
                    ForEach(pre.bodyPartCats, id: \.self) { category in
                        Text(category).tag(category)
                    }
                }
                .pickerStyle(WheelPickerStyle()).frame(height:100).padding(0)
            }

            Section(
                header:
                    HStack {
                        Text("Exercises")
                        Spacer()
                        Button {
                            withAnimation {
                                showPicker.toggle()
                            }
                        } label: {
                            Label("", systemImage: "plus.circle.fill")
                        }
                        .buttonStyle(BorderlessButtonStyle())
                    }
            ) {
                ForEach(item.description, id: \.self) { ex in
                    Text("• \(ex)")
                        .padding(.vertical, 4)
                }
                .onDelete { item.description.remove(atOffsets: $0) }
                .onMove { item.description.move(fromOffsets: $0, toOffset: $1) }

                if showPicker {
                    VStack(alignment: .leading, spacing: 10) {
                        Picker("Select an Exercise", selection: $selectedExercise) {
                            ForEach(pre.titles, id: \.self) { ex in
                                Text(ex).tag(ex)
                            }
                        }
                        .pickerStyle(MenuPickerStyle())
                        .padding(.vertical, 4)

                        Button(action: {
                            if !item.description.contains(selectedExercise) {
                                item.description.append(selectedExercise)
                                Task{
                                    await authState.StoreWorkouts(workout: item)
                                    //await authState.fetchWorkouts()
                                
                                }
                                
                            }
                            withAnimation {
                                showPicker = false
                            }
                        }) {
                            HStack {
                                Spacer()
                                Text("Confirm Add")
                                    .bold()
                                Spacer()
                            }
                        }
                        .padding(.vertical, 6)
                        .background(Color.accentColor.opacity(0.1))
                        .cornerRadius(8)
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .navigationTitle("Edit Workout")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                EditButton()
            }
        }
        .animation(.easeInOut, value: showPicker)
    }
}


struct CreateWorkout_Previews: PreviewProvider {
    struct PreviewWrapper: View {
        @State private var item = WorkoutItem(id: UUID().uuidString,
            title: "Title 1",
            description: ["Push Ups 3 x 12", "Lunges 3 x 10"],
            likes: 100,
            duration: 30 ,category: "Back"
        )

        var body: some View {
            NavigationStack {
                CreateWorkout(item: $item)
            }
        }
    }

    static var previews: some View {
        PreviewWrapper()
    }
}
