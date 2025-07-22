# C11S House iOS App - Onboarding UX Plan

# User flow edited by adrianco 22 July 2025 - do not modify this file

## Executive Summary

This document outlines the comprehensive user experience plan for onboarding new users to the C11S House iOS application. The onboarding flow is designed to be intuitive, progressive, and personalized, guiding users through essential setup while establishing an emotional connection with their "house consciousness."

## User Personas

### Primary Persona: Tech-Savvy Homeowner
- **Age**: 30-50
- **Technical Proficiency**: High
- **Goals**: Wants intelligent home management with minimal setup
- **Pain Points**: Complex configuration, privacy concerns
- **Needs**: Quick setup, clear value proposition, control over data

### Secondary Persona: Smart Home Enthusiast
- **Age**: 25-45
- **Technical Proficiency**: Medium to High
- **Goals**: Integrate with existing smart home ecosystem
- **Pain Points**: Compatibility issues, fragmented experiences
- **Needs**: Seamless integration, advanced features

### Tertiary Persona: Privacy-Conscious User
- **Age**: 35-60
- **Technical Proficiency**: Medium
- **Goals**: Home automation without compromising privacy
- **Pain Points**: Data collection, cloud dependencies
- **Needs**: Local processing, transparent permissions

## Onboarding Journey Map

### Phase 1: Welcome & First Impression (0-30 seconds)
**Goal**: Create emotional connection and establish trust

1. **Splash Screen**
   - Animated house icon with "consciousness" visualization
   - Tagline: "Your House, Awakened"
   - Permissions popup on first use
   - Smooth transition to main contentview screen

   NEW: Animate icon by flying the brain+circle into the house, ending up at the same location

### Phase 2: Permission & Setup (30 seconds - 2 minutes)
**Goal**: Obtain necessary permissions with clear explanations

1. **Core Permissions**
   - **Microphone**: "To hear your voice commands"
   - **Speech Recognition**: "To understand your requests"
   - **Location**: "To provide local weather and context"

   NEW: Add HomeKit "To find existing named rooms and devices"

2. **Location**
   -- Background lookup of location address, populating Address Note

NEW: 3. **HomeKit**
   -- Obtain the entire HomeKit configuration and format it as a summary in a single note, once this works create rooms and devices as individual notes.


### Phase 3: Personalization (2-4 minutes)
**Goal**: Gather essential information through conversational UI

1. **Invitation**
   - If "required" notes are not confirmed yet, show a message inviting the user to start a conversation to set things up. All conversations take place in the same chat style interface view. The only difference from normal conversations is the house leads the questions during setup. There are no new views. If required notes are have not got confirmed answers, the house is Curious and should be asking questions.

2. **Transition to Conversation**
   - Pre-load transcript with address from Note if available
   - Conversation question asking user to confirm address
   - IF speaker isn't muted, speak the question, then turn on microphone to listen for answer transcription. If speaker is muted, rely on text based conversation with no audio in/out.
   - Once address note has been saved by user, lookup weather based on that address as a background activity, save weather summary as a note and summarize on content view, with appropriate emotion response. If there is an error looking up weather, save a summary of the error in the note (during development, include full error log details).

2. **House Naming**
   - Second conversation question suggests house names based on address, pre-populated in transcript
   - Once house name note has been saved, update main contentview from "Your House" to show the chosen name

3. **User Introduction**
   - Conversational prompt: "What's your name'?"
   - Voice or text input options saved as a note
   - Use as part of personalized response from house

4. **Completion celebration**
   - Hi 'name', as the conscious mind for 'house name' at 'address' I'm going to keep an eye on things for you, help you answer questions about the house and help manage devices in various rooms".

### Phase 4: Add First Notes (4-5 minutes)
**Goal**: Showcase key features through interactive chat tutorial

1. **Conversation Tutorial**
   - Guided first conversation
   - "You can save notes about the rooms and things in the rooms around the house, what's the name of the room you are in now?"
   - Save a note name based on the response
   - "Tell me about the room, and things that are in it, that you might want to know about in the future. Are there any connected devices here, or things that you sometimes forget how to operate?"
   - Save the response in the body of the room note

2. **Notes Introduction**
   - If the user has not created any room or device notes yet start a conversation with
   - "You can see and edit the current notes from the main screen, and say something like 'new room note' or 'new device note' to start a conversation about something new"
   - If user creates a new device note, guess what room it is probably in and ask the user to confirm "is this device in this room or somewhere else? Leave this blank if it's not part of a room"

3. **Mood & Personality**
   - Show house emotions with Weather-based mood changes
   - If there's nothing going on, start a conversation with "Hi!" and let the user enter something to respond to
   - Search note titles for basic notes recall. "What's the weather?" should match the word weather and load the current weather note into the response. 
   - Once the basic functionality is working, we will add Apple's CoreML AI to understand questions and summarize info based on the notes.


## Visual Design Principles

### Color Palette
- **Primary**: Blue gradient (#007AFF to #5856D6)
- **Secondary**: Teal to green for nature/weather
- **Accent**: Orange/pink for important actions
- **Semantic**: Green (success), Red (errors), Yellow (warnings)

### Typography
- **Headers**: SF Pro Display, Bold
- **Body**: SF Pro Text, Regular
- **Captions**: SF Pro Text, Light
- **Emphasis**: Medium weight for CTAs

### Motion & Animation
- **Transitions**: 0.3s ease-in-out
- **Micro-interactions**: Subtle bounces and scales
- **Loading states**: Skeleton screens, not spinners
- **Feedback**: Immediate visual response to all actions



## Conclusion

This onboarding plan creates a delightful first experience that balances efficiency with personality. By treating the house as a character rather than a tool, we establish an emotional connection that encourages daily engagement while respecting user privacy and preferences.