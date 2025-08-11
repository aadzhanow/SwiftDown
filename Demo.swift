import SwiftUI
import SwiftDown

struct DemoView: View {
    @State private var text = """
    # Project Kickoff Meeting – Transcript
    
    **Date:** August 10, 2025
    **Attendees:** Alice, Bob, Charlie, Diana, Ethan
    
    ## Agenda
    1. Project updates
    2. Timeline adjustments
    3. Budget review
    4. Q&A session
    5. Action items
    
    ---
    
    ## 1. Project Updates
    
    **Alice:** The development team has finalized the authentication module. This includes:
    - Sign-up with email and password
    - OAuth with Google and Apple
    - Basic account settings page
    
    **Bob:** UI team delivered the first version of the onboarding flow. Still pending:
    - Localization in Spanish and German  
    - Accessibility improvements
    - *Dark mode optimization*
    
    ---
    
    ## 2. Timeline Adjustments
    
    - Original deadline: **September 30, 2025**
    - Proposed new deadline: **October 15, 2025**
    - Reason: Integration testing and additional QA
    """
    
    @State private var hideSymbols = false
    
    var body: some View {
        VStack {
            Toggle("Hide Markdown Symbols", isOn: $hideSymbols)
                .padding()
            
            SwiftDownEditor(
                text: $text,
                hideMarkdownSymbols: hideSymbols
            )
            .theme(.BuiltIn.defaultLight.theme())
            .padding()
        }
    }
}

struct DemoView_Previews: PreviewProvider {
    static var previews: some View {
        DemoView()
    }
}