import UserNotifications
import Foundation

class NotificationService {
    static let shared = NotificationService()
    
    func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if granted {
                print("Notification permission granted")
                self.scheduleNotifications()
            } else {
                print("Notification permission denied")
            }
        }
    }
    
    func scheduleNotifications() {
        scheduleQuarterlyMagazineNotifications()
        scheduleWeeklyArticleReminder()
    }
    
    private func scheduleQuarterlyMagazineNotifications() {
        let center = UNUserNotificationCenter.current()
        
        // Define the quarterly dates with their corresponding seasons
        let quarterlyDatesAndSeasons = [
            (DateComponents(month: 4, day: 2, hour: 9, minute: 0), "Spring"),   // April
            (DateComponents(month: 7, day: 2, hour: 9, minute: 0), "Summer"),   // July
            (DateComponents(month: 10, day: 2, hour: 9, minute: 0), "Autumn"),  // October
            (DateComponents(month: 1, day: 2, hour: 9, minute: 0), "Winter")    // January
        ]
        
        for (dateComponents, season) in quarterlyDatesAndSeasons {
            let content = UNMutableNotificationContent()
            content.title = "New Magazine Issue Available!"
            content.body = "The new POLO&Lifestyle Magazine \(season) issue is now available"
            content.sound = .default
            
            // Create trigger in user's time zone
            var localDateComponents = dateComponents
            localDateComponents.timeZone = Calendar.current.timeZone // Use local time zone
            let trigger = UNCalendarNotificationTrigger(dateMatching: localDateComponents, repeats: true)
            let request = UNNotificationRequest(identifier: "magazine-\(season)", content: content, trigger: trigger)
            
            center.add(request)
        }
    }
    
    private func scheduleWeeklyArticleReminder() {
        let center = UNUserNotificationCenter.current()
        
        var dateComponents = DateComponents()
        dateComponents.weekday = 7 // Saturday
        dateComponents.hour = 9    // Local 9am
        dateComponents.minute = 0
        dateComponents.timeZone = Calendar.current.timeZone // Use local time zone
        
        let content = UNMutableNotificationContent()
        content.title = "Weekly Articles Reminder"
        content.body = "Don't miss out on the latest POLO&Lifestyle articles"
        content.sound = .default
        
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        let request = UNNotificationRequest(identifier: "weekly-reminder", content: content, trigger: trigger)
        
        center.add(request)
    }
    
    // Add these new test methods
    func triggerTestNotifications() {
        triggerTestMagazineNotification()
        triggerTestWeeklyNotification()
    }
    
    private func triggerTestMagazineNotification() {
        let content = UNMutableNotificationContent()
        content.title = "New Magazine Issue Available!"
        
        // Determine current season for test notification
        let currentMonth = Calendar.current.component(.month, from: Date())
        let season = switch currentMonth {
        case 4...6: "Spring"
        case 7...9: "Summer"
        case 10...12: "Autumn"
        default: "Winter"
        }
        
        content.body = "The new Polo&Lifestyle Magazine \(season) issue is now available"
        content.sound = .default
        
        // Trigger after 5 seconds
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 5, repeats: false)
        let request = UNNotificationRequest(identifier: "test-magazine", content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request)
    }
    
    private func triggerTestWeeklyNotification() {
        let content = UNMutableNotificationContent()
        content.title = "Weekly Articles Reminder"
        content.body = "Don't miss out on the latest Polo&Lifestyle articles"
        content.sound = .default
        
        // Trigger after 10 seconds
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 10, repeats: false)
        let request = UNNotificationRequest(identifier: "test-weekly", content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request)
    }
} 