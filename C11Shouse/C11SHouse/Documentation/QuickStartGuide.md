# Quick Start Guide for HouseThoughts Q&A System

## Current Implementation

The Q&A system is integrated into the ConversationView:
- **HouseThoughts** displays the current question
- **Transcript area** is where users provide their answer
- **Save button** appears when there's a question and an answer
- Only one Q&A pair is visible at a time

## First Question
The system starts with "What's your name?" - this asks for the **user's name**, not the house name.
Once saved, the user's name replaces "Real-time Transcript:" with "[Name]'s Response:"

## How to Add More Questions

Edit `/C11Shouse/C11SHouse/Models/NotesStore.swift`:

```swift
extension Question {
    static let predefinedQuestions: [Question] = [
        Question(
            text: "What's your name?",
            category: .personal,
            displayOrder: 1,
            isRequired: true,
            hint: "Your name"
        ),
        // Add new questions here:
        Question(
            text: "What's your favorite room temperature?",
            category: .preferences,
            displayOrder: 2,
            isRequired: false,
            hint: "Temperature in Fahrenheit"
        ),
        // More questions...
    ]
}
```

## Question Categories
- `.personal` - Personal information
- `.houseInfo` - House details  
- `.maintenance` - Maintenance records
- `.preferences` - User preferences
- `.reminders` - Reminders and notes
- `.other` - Miscellaneous

## How It Works
1. App loads first unanswered question
2. Question appears in HouseThoughts display
3. User speaks or types answer in transcript
4. Save button stores the answer as a "note"
5. Next unanswered question loads automatically

## Future House Name
The house name feature will be implemented separately. For now, the app uses "Your House" as a placeholder.