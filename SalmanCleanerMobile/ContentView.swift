import SwiftUI

struct ContentView: View {
    var body: some View {
        NavigationView {
            VStack {
                Image(systemName: "sparkles")
                    .imageScale(.large)
                    .foregroundColor(.accentColor)
                Text("SalmanCleaner Mobile")
                    .font(.headline)
            }
            .navigationTitle("Dashboard")
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
