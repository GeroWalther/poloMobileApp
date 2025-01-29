import SwiftUI

struct PoloLifestyleHeader: View {
    var body: some View {
        HStack(alignment: .lastTextBaseline, spacing: 2) {
            Text("POLO")
                .font(.custom("Times New Roman", size: 48))
                .foregroundColor(.black)
            Text("&")
                .font(.custom("Times New Roman", size: 18))
                .foregroundColor(.black)
            Text("LIFESTYLE")
                .font(.custom("Times New Roman", size: 32))
                .foregroundColor(.black)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
} 
