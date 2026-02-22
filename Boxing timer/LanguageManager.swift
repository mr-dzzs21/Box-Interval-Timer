//
//  LanguageManager.swift
//  Boxing timer
//

import Foundation
import SwiftUI
import Combine

// Lokalisierung für IntervalDevice
extension IntervalDevice {
    func localizedName(_ t: Translations) -> String {
        switch self {
        case .running:   return t.deviceRunning
        case .treadmill: return t.deviceTreadmill
        case .airBike:   return t.deviceAirBike
        case .bagWork:   return t.deviceBagWork
        }
    }
}

// Lokalisierung für IntervalLevel
extension IntervalLevel {
    func localizedName(_ t: Translations) -> String {
        switch self {
        case .beginner:     return t.levelBeginner
        case .intermediate: return t.levelIntermediate
        case .advanced:     return t.levelAdvanced
        }
    }
}

// Die 5 unterstützten Sprachen
enum AppLanguage: String, CaseIterable, Codable {
    case german  = "de"
    case english = "en"
    case arabic  = "ar"
    case spanish = "es"
    case french  = "fr"

    var displayName: String {
        switch self {
        case .german:  return "🇩🇪 Deutsch"
        case .english: return "🇬🇧 English"
        case .arabic:  return "🇸🇦 العربية"
        case .spanish: return "🇪🇸 Español"
        case .french:  return "🇫🇷 Français"
        }
    }

    // Arabisch liest von rechts nach links
    var layoutDirection: LayoutDirection {
        return self == .arabic ? .rightToLeft : .leftToRight
    }
}

// Speichert die gewählte Sprache und stellt Übersetzungen bereit
class LanguageManager: ObservableObject {
    @Published var current: AppLanguage {
        didSet {
            UserDefaults.standard.set(current.rawValue, forKey: "appLanguage")
        }
    }

    init() {
        let saved = UserDefaults.standard.string(forKey: "appLanguage") ?? "de"
        self.current = AppLanguage(rawValue: saved) ?? .german
    }

    // Kurzform: lang.t.xxx
    var t: Translations {
        Translations.all[current] ?? Translations.all[.german]!
    }
}

// Alle Texte der App in einer Struktur
struct Translations {

    // Timer-Phasen
    let phaseWarmUp: String
    let phaseRest: String
    let phaseCoolDown: String
    let phaseFinished: String
    let phaseWork: String
    let phaseRound: String

    // Tab-Leiste
    let tabFightTimer: String
    let tabIntervals: String
    let tabHistory: String
    let tabStats: String
    let tabSettings: String

    // Fight Timer
    let fightTimerTitle: String
    let chooseTimer: String
    let standardPresets: String
    let customProfiles: String
    let customizations: String
    let warmUp: String
    let rounds: String
    let roundTime: String
    let rest: String
    let cancel: String
    let done: String
    let newProfile: String
    let profileNameHint: String
    let save: String

    // Interval Timer
    let intervalTitle: String
    let chooseTraining: String
    let preset: String
    let customSetting: String
    let device: String
    let level: String
    let yourTraining: String
    let intervals: String
    let coolDown: String
    let totalApprox: String
    let startTraining: String
    let work: String
    let back: String
    let saveWorkout: String
    let saved: String

    // Kampfsport-Namen (nur die, die sich wirklich ändern)
    let sportBoxen: String
    let sportRingen: String

    // IntervalDevice Namen
    let deviceRunning: String
    let deviceTreadmill: String
    let deviceAirBike: String
    let deviceBagWork: String

    // IntervalLevel Namen
    let levelBeginner: String
    let levelIntermediate: String
    let levelAdvanced: String

    // History
    let historyTitle: String
    let noWorkouts: String
    let noWorkoutsDesc: String
    let deleteAll: String
    let confirmDeleteAll: String
    let workoutDetails: String
    let general: String
    let sport: String
    let mode: String
    let date: String
    let duration: String
    let fightTimerDetails: String
    let intervalDetails: String

    // Statistiken
    let statsTitle: String
    let thisWeek: String
    let totalTime: String
    let favoriteSport: String
    let streak: String
    let workoutsLabel: String

    // Einstellungen
    let settingsTitle: String
    let audioHaptic: String
    let soundEnabled: String
    let vibrationEnabled: String
    let language: String
    let about: String
    let version: String
    let developer: String
    let presetsInfo: String
    let ok: String

    // Todos
    let tabTodos: String
    let todosTitle: String
    let todoAdd: String
    let todoPlaceholder: String
    let todoOpen: String
    let todoDone: String
    let todoEmpty: String
    let todoEmptyDesc: String

    // Übersetzt den internen Preset-Namen in die gewählte Sprache
    // Nur Boxen und Ringen ändern sich – MMA, K1, Judo etc. bleiben gleich
    func localizedPresetName(_ name: String) -> String {
        if name.contains("Boxen") || name.contains("Boxing") {
            return "🥊 " + sportBoxen
        }
        if name.contains("Ringen") || name.contains("Wrestling") {
            return "🤼 " + sportRingen
        }
        return name
    }

    // Alle Sprachen
    static let all: [AppLanguage: Translations] = [

        .german: Translations(
            phaseWarmUp: "WARM UP", phaseRest: "PAUSE", phaseCoolDown: "COOL DOWN",
            phaseFinished: "FERTIG!", phaseWork: "WORK", phaseRound: "RUNDE",
            tabFightTimer: "Fight Timer", tabIntervals: "Intervals",
            tabHistory: "History", tabStats: "Stats", tabSettings: "Settings",
            fightTimerTitle: "Fight Timer", chooseTimer: "Timer wählen",
            standardPresets: "Standard Presets", customProfiles: "Custom Profile",
            customizations: "Anpassungen", warmUp: "Warm-up", rounds: "Runden",
            roundTime: "Rundenzeit", rest: "Pause", cancel: "Abbrechen", done: "Fertig",
            newProfile: "Neues Profil", profileNameHint: "Profilname (z.B. Sambo)", save: "Speichern",
            intervalTitle: "Intervall Training", chooseTraining: "Wähle dein Training",
            preset: "Preset", customSetting: "Eigene Einstellung", device: "Gerät", level: "Level",
            yourTraining: "Dein Training:", intervals: "Intervalle", coolDown: "Cool-down",
            totalApprox: "Gesamt: ca.", startTraining: "Training starten", work: "Work",
            back: "Zurück", saveWorkout: "Workout speichern", saved: "Gespeichert!",
            sportBoxen: "Boxen", sportRingen: "Ringen",
            deviceRunning: "🏃 Draußen laufen", deviceTreadmill: "🏋️ Laufband",
            deviceAirBike: "🚴 AirBike", deviceBagWork: "🥊 Sandsack",
            levelBeginner: "Anfänger", levelIntermediate: "Fortgeschritten", levelAdvanced: "Profi",
            historyTitle: "History", noWorkouts: "Keine Workouts",
            noWorkoutsDesc: "Deine abgeschlossenen Workouts erscheinen hier",
            deleteAll: "Alle löschen", confirmDeleteAll: "Alle Workouts löschen?",
            workoutDetails: "Workout Details", general: "Allgemein", sport: "Sportart",
            mode: "Modus", date: "Datum", duration: "Dauer",
            fightTimerDetails: "Fight Timer Details", intervalDetails: "Interval Details",
            statsTitle: "Statistiken", thisWeek: "Diese Woche", totalTime: "Gesamt Zeit",
            favoriteSport: "Lieblings-Sport", streak: "Streak", workoutsLabel: "Workouts",
            settingsTitle: "Einstellungen", audioHaptic: "Audio & Haptik",
            soundEnabled: "Sound aktiviert", vibrationEnabled: "Vibration aktiviert",
            language: "Sprache", about: "Über die App", version: "Version",
            developer: "Developer", presetsInfo: "Presets Info", ok: "OK",
            tabTodos: "Todos", todosTitle: "Meine Todos", todoAdd: "Hinzufügen",
            todoPlaceholder: "Neues Todo...", todoOpen: "Offen", todoDone: "Erledigt",
            todoEmpty: "Keine Todos", todoEmptyDesc: "Füge dein erstes Todo hinzu"
        ),

        .english: Translations(
            phaseWarmUp: "WARM UP", phaseRest: "REST", phaseCoolDown: "COOL DOWN",
            phaseFinished: "DONE!", phaseWork: "WORK", phaseRound: "ROUND",
            tabFightTimer: "Fight Timer", tabIntervals: "Intervals",
            tabHistory: "History", tabStats: "Stats", tabSettings: "Settings",
            fightTimerTitle: "Fight Timer", chooseTimer: "Choose Timer",
            standardPresets: "Standard Presets", customProfiles: "Custom Profiles",
            customizations: "Customizations", warmUp: "Warm-up", rounds: "Rounds",
            roundTime: "Round Time", rest: "Rest", cancel: "Cancel", done: "Done",
            newProfile: "New Profile", profileNameHint: "Profile name (e.g. Sambo)", save: "Save",
            intervalTitle: "Interval Training", chooseTraining: "Choose your training",
            preset: "Preset", customSetting: "Custom", device: "Device", level: "Level",
            yourTraining: "Your training:", intervals: "Intervals", coolDown: "Cool-down",
            totalApprox: "Total: approx.", startTraining: "Start Training", work: "Work",
            back: "Back", saveWorkout: "Save Workout", saved: "Saved!",
            sportBoxen: "Boxing", sportRingen: "Wrestling",
            deviceRunning: "🏃 Outdoor Running", deviceTreadmill: "🏋️ Treadmill",
            deviceAirBike: "🚴 Air Bike", deviceBagWork: "🥊 Bag Work",
            levelBeginner: "Beginner", levelIntermediate: "Intermediate", levelAdvanced: "Advanced",
            historyTitle: "History", noWorkouts: "No Workouts",
            noWorkoutsDesc: "Your completed workouts will appear here",
            deleteAll: "Delete All", confirmDeleteAll: "Delete all workouts?",
            workoutDetails: "Workout Details", general: "General", sport: "Sport",
            mode: "Mode", date: "Date", duration: "Duration",
            fightTimerDetails: "Fight Timer Details", intervalDetails: "Interval Details",
            statsTitle: "Statistics", thisWeek: "This Week", totalTime: "Total Time",
            favoriteSport: "Favorite Sport", streak: "Streak", workoutsLabel: "Workouts",
            settingsTitle: "Settings", audioHaptic: "Audio & Haptics",
            soundEnabled: "Sound enabled", vibrationEnabled: "Vibration enabled",
            language: "Language", about: "About", version: "Version",
            developer: "Developer", presetsInfo: "Presets Info", ok: "OK",
            tabTodos: "Todos", todosTitle: "My Todos", todoAdd: "Add",
            todoPlaceholder: "New todo...", todoOpen: "Open", todoDone: "Done",
            todoEmpty: "No Todos", todoEmptyDesc: "Add your first todo"
        ),

        .arabic: Translations(
            phaseWarmUp: "إحماء", phaseRest: "راحة", phaseCoolDown: "تبريد",
            phaseFinished: "!انتهى", phaseWork: "تمرين", phaseRound: "جولة",
            tabFightTimer: "مؤقت القتال", tabIntervals: "فترات",
            tabHistory: "السجل", tabStats: "إحصاءات", tabSettings: "إعدادات",
            fightTimerTitle: "مؤقت القتال", chooseTimer: "اختر المؤقت",
            standardPresets: "الإعدادات الافتراضية", customProfiles: "ملفات مخصصة",
            customizations: "تخصيصات", warmUp: "إحماء", rounds: "جولات",
            roundTime: "وقت الجولة", rest: "راحة", cancel: "إلغاء", done: "تم",
            newProfile: "ملف جديد", profileNameHint: "اسم الملف (مثال: سامبو)", save: "حفظ",
            intervalTitle: "تدريب الفترات", chooseTraining: "اختر تدريبك",
            preset: "مُعد مسبقاً", customSetting: "مخصص", device: "الجهاز", level: "المستوى",
            yourTraining: ":تدريبك", intervals: "فترات", coolDown: "تبريد",
            totalApprox: "المجموع: تقريباً", startTraining: "ابدأ التدريب", work: "تمرين",
            back: "رجوع", saveWorkout: "حفظ التمرين", saved: "!تم الحفظ",
            sportBoxen: "ملاكمة", sportRingen: "مصارعة",
            deviceRunning: "🏃 الجري الخارجي", deviceTreadmill: "🏋️ جهاز الجري",
            deviceAirBike: "🚴 دراجة هوائية", deviceBagWork: "🥊 كيس الملاكمة",
            levelBeginner: "مبتدئ", levelIntermediate: "متوسط", levelAdvanced: "محترف",
            historyTitle: "السجل", noWorkouts: "لا توجد تمارين",
            noWorkoutsDesc: "ستظهر هنا تمارينك المكتملة",
            deleteAll: "حذف الكل", confirmDeleteAll: "حذف جميع التمارين؟",
            workoutDetails: "تفاصيل التمرين", general: "عام", sport: "الرياضة",
            mode: "الوضع", date: "التاريخ", duration: "المدة",
            fightTimerDetails: "تفاصيل مؤقت القتال", intervalDetails: "تفاصيل الفترات",
            statsTitle: "إحصاءات", thisWeek: "هذا الأسبوع", totalTime: "إجمالي الوقت",
            favoriteSport: "الرياضة المفضلة", streak: "تسلسل", workoutsLabel: "تمارين",
            settingsTitle: "إعدادات", audioHaptic: "الصوت والاهتزاز",
            soundEnabled: "تفعيل الصوت", vibrationEnabled: "تفعيل الاهتزاز",
            language: "اللغة", about: "عن التطبيق", version: "الإصدار",
            developer: "المطور", presetsInfo: "معلومات الإعدادات", ok: "موافق",
            tabTodos: "مهام", todosTitle: "مهامي", todoAdd: "إضافة",
            todoPlaceholder: "مهمة جديدة...", todoOpen: "مفتوح", todoDone: "منجز",
            todoEmpty: "لا توجد مهام", todoEmptyDesc: "أضف مهمتك الأولى"
        ),

        .spanish: Translations(
            phaseWarmUp: "CALENTAMIENTO", phaseRest: "DESCANSO", phaseCoolDown: "ENFRIAMIENTO",
            phaseFinished: "¡LISTO!", phaseWork: "TRABAJO", phaseRound: "RONDA",
            tabFightTimer: "Cronómetro", tabIntervals: "Intervalos",
            tabHistory: "Historial", tabStats: "Estadísticas", tabSettings: "Ajustes",
            fightTimerTitle: "Cronómetro", chooseTimer: "Elegir Cronómetro",
            standardPresets: "Ajustes Estándar", customProfiles: "Perfiles Personalizados",
            customizations: "Personalizaciones", warmUp: "Calentamiento", rounds: "Rondas",
            roundTime: "Tiempo de Ronda", rest: "Descanso", cancel: "Cancelar", done: "Listo",
            newProfile: "Nuevo Perfil", profileNameHint: "Nombre del perfil (ej. Sambo)", save: "Guardar",
            intervalTitle: "Entrenamiento por Intervalos", chooseTraining: "Elige tu entrenamiento",
            preset: "Predefinido", customSetting: "Personalizado", device: "Equipo", level: "Nivel",
            yourTraining: "Tu entrenamiento:", intervals: "Intervalos", coolDown: "Enfriamiento",
            totalApprox: "Total: aprox.", startTraining: "Iniciar Entrenamiento", work: "Trabajo",
            back: "Atrás", saveWorkout: "Guardar Entrenamiento", saved: "¡Guardado!",
            sportBoxen: "Boxeo", sportRingen: "Lucha",
            deviceRunning: "🏃 Correr al aire libre", deviceTreadmill: "🏋️ Cinta de correr",
            deviceAirBike: "🚴 Bicicleta Air", deviceBagWork: "🥊 Saco de boxeo",
            levelBeginner: "Principiante", levelIntermediate: "Intermedio", levelAdvanced: "Avanzado",
            historyTitle: "Historial", noWorkouts: "Sin Entrenamientos",
            noWorkoutsDesc: "Tus entrenamientos completados aparecerán aquí",
            deleteAll: "Eliminar Todo", confirmDeleteAll: "¿Eliminar todos los entrenamientos?",
            workoutDetails: "Detalles del Entrenamiento", general: "General", sport: "Deporte",
            mode: "Modo", date: "Fecha", duration: "Duración",
            fightTimerDetails: "Detalles del Cronómetro", intervalDetails: "Detalles de Intervalos",
            statsTitle: "Estadísticas", thisWeek: "Esta Semana", totalTime: "Tiempo Total",
            favoriteSport: "Deporte Favorito", streak: "Racha", workoutsLabel: "Entrenamientos",
            settingsTitle: "Ajustes", audioHaptic: "Audio y Háptico",
            soundEnabled: "Sonido activado", vibrationEnabled: "Vibración activada",
            language: "Idioma", about: "Acerca de", version: "Versión",
            developer: "Desarrollador", presetsInfo: "Info de Presets", ok: "OK",
            tabTodos: "Tareas", todosTitle: "Mis Tareas", todoAdd: "Añadir",
            todoPlaceholder: "Nueva tarea...", todoOpen: "Pendiente", todoDone: "Hecho",
            todoEmpty: "Sin tareas", todoEmptyDesc: "Añade tu primera tarea"
        ),

        .french: Translations(
            phaseWarmUp: "ÉCHAUFFEMENT", phaseRest: "REPOS", phaseCoolDown: "RÉCUPÉRATION",
            phaseFinished: "TERMINÉ!", phaseWork: "TRAVAIL", phaseRound: "ROUND",
            tabFightTimer: "Chrono Combat", tabIntervals: "Intervalles",
            tabHistory: "Historique", tabStats: "Statistiques", tabSettings: "Réglages",
            fightTimerTitle: "Chrono Combat", chooseTimer: "Choisir le Chrono",
            standardPresets: "Préréglages Standards", customProfiles: "Profils Personnalisés",
            customizations: "Personnalisations", warmUp: "Échauffement", rounds: "Rounds",
            roundTime: "Durée du Round", rest: "Repos", cancel: "Annuler", done: "Terminer",
            newProfile: "Nouveau Profil", profileNameHint: "Nom du profil (ex. Sambo)", save: "Enregistrer",
            intervalTitle: "Entraînement par Intervalles", chooseTraining: "Choisissez votre entraînement",
            preset: "Préréglage", customSetting: "Personnalisé", device: "Appareil", level: "Niveau",
            yourTraining: "Votre entraînement :", intervals: "Intervalles", coolDown: "Récupération",
            totalApprox: "Total : environ", startTraining: "Démarrer l'Entraînement", work: "Travail",
            back: "Retour", saveWorkout: "Enregistrer l'entraînement", saved: "Enregistré !",
            sportBoxen: "Boxe", sportRingen: "Lutte",
            deviceRunning: "🏃 Course en plein air", deviceTreadmill: "🏋️ Tapis de course",
            deviceAirBike: "🚴 Vélo Air", deviceBagWork: "🥊 Sac de frappe",
            levelBeginner: "Débutant", levelIntermediate: "Intermédiaire", levelAdvanced: "Avancé",
            historyTitle: "Historique", noWorkouts: "Aucun entraînement",
            noWorkoutsDesc: "Vos entraînements terminés apparaîtront ici",
            deleteAll: "Tout supprimer", confirmDeleteAll: "Supprimer tous les entraînements ?",
            workoutDetails: "Détails de l'entraînement", general: "Général", sport: "Sport",
            mode: "Mode", date: "Date", duration: "Durée",
            fightTimerDetails: "Détails du Chrono", intervalDetails: "Détails des Intervalles",
            statsTitle: "Statistiques", thisWeek: "Cette Semaine", totalTime: "Temps Total",
            favoriteSport: "Sport Favori", streak: "Série", workoutsLabel: "Entraînements",
            settingsTitle: "Réglages", audioHaptic: "Audio & Haptique",
            soundEnabled: "Son activé", vibrationEnabled: "Vibration activée",
            language: "Langue", about: "À propos", version: "Version",
            developer: "Développeur", presetsInfo: "Info Préréglages", ok: "OK",
            tabTodos: "Tâches", todosTitle: "Mes Tâches", todoAdd: "Ajouter",
            todoPlaceholder: "Nouvelle tâche...", todoOpen: "En cours", todoDone: "Terminé",
            todoEmpty: "Aucune tâche", todoEmptyDesc: "Ajoutez votre première tâche"
        )
    ]
}
