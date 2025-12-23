import Foundation

struct Car: Identifiable, Codable, Equatable {
    let id: UUID
    var make: String
    var model: String
    var year: Int?
    var tankCapacity: Double // in liters
    var imageData: Data?
    
    init(
        id: UUID = UUID(),
        make: String,
        model: String,
        year: Int? = nil,
        tankCapacity: Double,
        imageData: Data? = nil
    ) {
        self.id = id
        self.make = make
        self.model = model
        self.year = year
        self.tankCapacity = tankCapacity
        self.imageData = imageData
    }
    
    var displayName: String {
        if let year {
            return "\(year) \(make) \(model)"
        }
        return "\(make) \(model)"
    }
}

// MARK: - Car Database (Turkey & Qatar Markets)

enum CarDatabase {
    struct CarModel: Identifiable, Hashable {
        let id = UUID()
        let name: String
        let tankCapacity: Double // liters

        func hash(into hasher: inout Hasher) {
            hasher.combine(name)
            hasher.combine(tankCapacity)
        }

        static func == (lhs: CarModel, rhs: CarModel) -> Bool {
            lhs.name == rhs.name && lhs.tankCapacity == rhs.tankCapacity
        }
    }

    struct CarMake: Identifiable, Hashable {
        let id = UUID()
        let name: String
        let models: [CarModel]

        func hash(into hasher: inout Hasher) {
            hasher.combine(name)
            hasher.combine(models)
        }

        static func == (lhs: CarMake, rhs: CarMake) -> Bool {
            lhs.name == rhs.name && lhs.models == rhs.models
        }
    }
    
    static let makes: [CarMake] = [
        // Japanese Brands
        CarMake(name: "Toyota", models: [
            CarModel(name: "Corolla", tankCapacity: 50),
            CarModel(name: "Corolla Cross", tankCapacity: 47),
            CarModel(name: "Camry", tankCapacity: 60),
            CarModel(name: "RAV4", tankCapacity: 55),
            CarModel(name: "C-HR", tankCapacity: 50),
            CarModel(name: "Yaris", tankCapacity: 42),
            CarModel(name: "Yaris Cross", tankCapacity: 42),
            CarModel(name: "Land Cruiser", tankCapacity: 93),
            CarModel(name: "Land Cruiser 300", tankCapacity: 110),
            CarModel(name: "Land Cruiser Prado", tankCapacity: 87),
            CarModel(name: "Hilux", tankCapacity: 80),
            CarModel(name: "Fortuner", tankCapacity: 80),
            CarModel(name: "Supra", tankCapacity: 52),
            CarModel(name: "Avalon", tankCapacity: 60),
            CarModel(name: "Sequoia", tankCapacity: 100),
            CarModel(name: "4Runner", tankCapacity: 87),
            CarModel(name: "Tundra", tankCapacity: 100),
            CarModel(name: "bZ4X", tankCapacity: 0), // Electric
            CarModel(name: "Crown", tankCapacity: 55)
        ]),
        CarMake(name: "Honda", models: [
            CarModel(name: "Civic", tankCapacity: 47),
            CarModel(name: "Civic Type R", tankCapacity: 47),
            CarModel(name: "Accord", tankCapacity: 56),
            CarModel(name: "CR-V", tankCapacity: 57),
            CarModel(name: "HR-V", tankCapacity: 40),
            CarModel(name: "Pilot", tankCapacity: 74),
            CarModel(name: "City", tankCapacity: 40),
            CarModel(name: "Jazz", tankCapacity: 40),
            CarModel(name: "ZR-V", tankCapacity: 53),
            CarModel(name: "Passport", tankCapacity: 74)
        ]),
        CarMake(name: "Nissan", models: [
            CarModel(name: "Altima", tankCapacity: 61),
            CarModel(name: "Maxima", tankCapacity: 68),
            CarModel(name: "Patrol", tankCapacity: 140),
            CarModel(name: "Patrol Nismo", tankCapacity: 140),
            CarModel(name: "X-Trail", tankCapacity: 60),
            CarModel(name: "Qashqai", tankCapacity: 55),
            CarModel(name: "Juke", tankCapacity: 46),
            CarModel(name: "Pathfinder", tankCapacity: 74),
            CarModel(name: "Sunny", tankCapacity: 41),
            CarModel(name: "Kicks", tankCapacity: 41),
            CarModel(name: "Navara", tankCapacity: 80),
            CarModel(name: "Z", tankCapacity: 62),
            CarModel(name: "GT-R", tankCapacity: 74),
            CarModel(name: "Armada", tankCapacity: 98),
            CarModel(name: "Murano", tankCapacity: 72),
            CarModel(name: "Sentra", tankCapacity: 50)
        ]),
        CarMake(name: "Mazda", models: [
            CarModel(name: "3", tankCapacity: 51),
            CarModel(name: "6", tankCapacity: 62),
            CarModel(name: "CX-3", tankCapacity: 48),
            CarModel(name: "CX-30", tankCapacity: 51),
            CarModel(name: "CX-5", tankCapacity: 58),
            CarModel(name: "CX-60", tankCapacity: 58),
            CarModel(name: "CX-9", tankCapacity: 74),
            CarModel(name: "CX-90", tankCapacity: 74),
            CarModel(name: "MX-5", tankCapacity: 45),
            CarModel(name: "BT-50", tankCapacity: 80)
        ]),
        CarMake(name: "Mitsubishi", models: [
            CarModel(name: "Lancer", tankCapacity: 59),
            CarModel(name: "Outlander", tankCapacity: 60),
            CarModel(name: "ASX", tankCapacity: 60),
            CarModel(name: "Eclipse Cross", tankCapacity: 60),
            CarModel(name: "Pajero", tankCapacity: 88),
            CarModel(name: "Pajero Sport", tankCapacity: 68),
            CarModel(name: "L200", tankCapacity: 75),
            CarModel(name: "Attrage", tankCapacity: 42),
            CarModel(name: "Xpander", tankCapacity: 45)
        ]),
        CarMake(name: "Suzuki", models: [
            CarModel(name: "Swift", tankCapacity: 37),
            CarModel(name: "Vitara", tankCapacity: 47),
            CarModel(name: "S-Cross", tankCapacity: 47),
            CarModel(name: "Jimny", tankCapacity: 40),
            CarModel(name: "Celerio", tankCapacity: 35),
            CarModel(name: "Ciaz", tankCapacity: 43),
            CarModel(name: "Ertiga", tankCapacity: 45),
            CarModel(name: "Dzire", tankCapacity: 37),
            CarModel(name: "Baleno", tankCapacity: 37)
        ]),
        CarMake(name: "Subaru", models: [
            CarModel(name: "Impreza", tankCapacity: 63),
            CarModel(name: "WRX", tankCapacity: 63),
            CarModel(name: "Legacy", tankCapacity: 70),
            CarModel(name: "Outback", tankCapacity: 70),
            CarModel(name: "Forester", tankCapacity: 63),
            CarModel(name: "XV", tankCapacity: 63),
            CarModel(name: "BRZ", tankCapacity: 50),
            CarModel(name: "Crosstrek", tankCapacity: 63),
            CarModel(name: "Solterra", tankCapacity: 0) // Electric
        ]),
        CarMake(name: "Lexus", models: [
            CarModel(name: "IS", tankCapacity: 66),
            CarModel(name: "ES", tankCapacity: 60),
            CarModel(name: "LS", tankCapacity: 82),
            CarModel(name: "RC", tankCapacity: 66),
            CarModel(name: "LC", tankCapacity: 82),
            CarModel(name: "UX", tankCapacity: 47),
            CarModel(name: "NX", tankCapacity: 55),
            CarModel(name: "RX", tankCapacity: 72),
            CarModel(name: "GX", tankCapacity: 87),
            CarModel(name: "LX", tankCapacity: 93),
            CarModel(name: "RZ", tankCapacity: 0) // Electric
        ]),
        CarMake(name: "Infiniti", models: [
            CarModel(name: "Q50", tankCapacity: 74),
            CarModel(name: "Q60", tankCapacity: 74),
            CarModel(name: "QX50", tankCapacity: 68),
            CarModel(name: "QX55", tankCapacity: 68),
            CarModel(name: "QX60", tankCapacity: 74),
            CarModel(name: "QX80", tankCapacity: 98)
        ]),
        
        // Korean Brands
        CarMake(name: "Hyundai", models: [
            CarModel(name: "i10", tankCapacity: 35),
            CarModel(name: "i20", tankCapacity: 45),
            CarModel(name: "i30", tankCapacity: 50),
            CarModel(name: "Elantra", tankCapacity: 50),
            CarModel(name: "Sonata", tankCapacity: 60),
            CarModel(name: "Accent", tankCapacity: 43),
            CarModel(name: "Tucson", tankCapacity: 54),
            CarModel(name: "Santa Fe", tankCapacity: 67),
            CarModel(name: "Palisade", tankCapacity: 71),
            CarModel(name: "Kona", tankCapacity: 50),
            CarModel(name: "Creta", tankCapacity: 50),
            CarModel(name: "Venue", tankCapacity: 45),
            CarModel(name: "Bayon", tankCapacity: 40),
            CarModel(name: "Staria", tankCapacity: 75),
            CarModel(name: "Ioniq 5", tankCapacity: 0), // Electric
            CarModel(name: "Ioniq 6", tankCapacity: 0), // Electric
            CarModel(name: "Azera", tankCapacity: 70)
        ]),
        CarMake(name: "Kia", models: [
            CarModel(name: "Picanto", tankCapacity: 35),
            CarModel(name: "Rio", tankCapacity: 45),
            CarModel(name: "Cerato", tankCapacity: 50),
            CarModel(name: "K5", tankCapacity: 60),
            CarModel(name: "Stinger", tankCapacity: 60),
            CarModel(name: "Sportage", tankCapacity: 54),
            CarModel(name: "Sorento", tankCapacity: 67),
            CarModel(name: "Telluride", tankCapacity: 71),
            CarModel(name: "Carnival", tankCapacity: 72),
            CarModel(name: "Soul", tankCapacity: 54),
            CarModel(name: "Seltos", tankCapacity: 50),
            CarModel(name: "Niro", tankCapacity: 43),
            CarModel(name: "EV6", tankCapacity: 0), // Electric
            CarModel(name: "EV9", tankCapacity: 0), // Electric
            CarModel(name: "K8", tankCapacity: 70)
        ]),
        CarMake(name: "Genesis", models: [
            CarModel(name: "G70", tankCapacity: 60),
            CarModel(name: "G80", tankCapacity: 72),
            CarModel(name: "G90", tankCapacity: 82),
            CarModel(name: "GV60", tankCapacity: 0), // Electric
            CarModel(name: "GV70", tankCapacity: 67),
            CarModel(name: "GV80", tankCapacity: 82)
        ]),
        
        // German Brands
        CarMake(name: "BMW", models: [
            CarModel(name: "1 Series", tankCapacity: 50),
            CarModel(name: "2 Series", tankCapacity: 52),
            CarModel(name: "3 Series", tankCapacity: 59),
            CarModel(name: "4 Series", tankCapacity: 59),
            CarModel(name: "5 Series", tankCapacity: 68),
            CarModel(name: "6 Series", tankCapacity: 68),
            CarModel(name: "7 Series", tankCapacity: 82),
            CarModel(name: "8 Series", tankCapacity: 68),
            CarModel(name: "X1", tankCapacity: 51),
            CarModel(name: "X2", tankCapacity: 51),
            CarModel(name: "X3", tankCapacity: 65),
            CarModel(name: "X4", tankCapacity: 65),
            CarModel(name: "X5", tankCapacity: 83),
            CarModel(name: "X6", tankCapacity: 83),
            CarModel(name: "X7", tankCapacity: 83),
            CarModel(name: "XM", tankCapacity: 69),
            CarModel(name: "Z4", tankCapacity: 52),
            CarModel(name: "iX", tankCapacity: 0), // Electric
            CarModel(name: "i4", tankCapacity: 0), // Electric
            CarModel(name: "i7", tankCapacity: 0), // Electric
            CarModel(name: "iX3", tankCapacity: 0), // Electric
            CarModel(name: "M2", tankCapacity: 52),
            CarModel(name: "M3", tankCapacity: 59),
            CarModel(name: "M4", tankCapacity: 59),
            CarModel(name: "M5", tankCapacity: 68),
            CarModel(name: "M8", tankCapacity: 68)
        ]),
        CarMake(name: "Mercedes-Benz", models: [
            CarModel(name: "A-Class", tankCapacity: 51),
            CarModel(name: "B-Class", tankCapacity: 51),
            CarModel(name: "C-Class", tankCapacity: 66),
            CarModel(name: "E-Class", tankCapacity: 66),
            CarModel(name: "S-Class", tankCapacity: 76),
            CarModel(name: "CLA", tankCapacity: 51),
            CarModel(name: "CLS", tankCapacity: 66),
            CarModel(name: "GLA", tankCapacity: 51),
            CarModel(name: "GLB", tankCapacity: 51),
            CarModel(name: "GLC", tankCapacity: 62),
            CarModel(name: "GLC Coupe", tankCapacity: 62),
            CarModel(name: "GLE", tankCapacity: 85),
            CarModel(name: "GLE Coupe", tankCapacity: 85),
            CarModel(name: "GLS", tankCapacity: 100),
            CarModel(name: "G-Class", tankCapacity: 100),
            CarModel(name: "SL", tankCapacity: 70),
            CarModel(name: "AMG GT", tankCapacity: 65),
            CarModel(name: "EQA", tankCapacity: 0), // Electric
            CarModel(name: "EQB", tankCapacity: 0), // Electric
            CarModel(name: "EQC", tankCapacity: 0), // Electric
            CarModel(name: "EQE", tankCapacity: 0), // Electric
            CarModel(name: "EQS", tankCapacity: 0), // Electric
            CarModel(name: "Maybach S-Class", tankCapacity: 76),
            CarModel(name: "Maybach GLS", tankCapacity: 100),
            CarModel(name: "V-Class", tankCapacity: 70)
        ]),
        CarMake(name: "Audi", models: [
            CarModel(name: "A1", tankCapacity: 45),
            CarModel(name: "A3", tankCapacity: 50),
            CarModel(name: "A4", tankCapacity: 58),
            CarModel(name: "A5", tankCapacity: 58),
            CarModel(name: "A6", tankCapacity: 73),
            CarModel(name: "A7", tankCapacity: 73),
            CarModel(name: "A8", tankCapacity: 82),
            CarModel(name: "Q2", tankCapacity: 50),
            CarModel(name: "Q3", tankCapacity: 60),
            CarModel(name: "Q5", tankCapacity: 75),
            CarModel(name: "Q7", tankCapacity: 85),
            CarModel(name: "Q8", tankCapacity: 85),
            CarModel(name: "TT", tankCapacity: 55),
            CarModel(name: "R8", tankCapacity: 83),
            CarModel(name: "e-tron", tankCapacity: 0), // Electric
            CarModel(name: "e-tron GT", tankCapacity: 0), // Electric
            CarModel(name: "Q4 e-tron", tankCapacity: 0), // Electric
            CarModel(name: "RS3", tankCapacity: 55),
            CarModel(name: "RS4", tankCapacity: 58),
            CarModel(name: "RS5", tankCapacity: 58),
            CarModel(name: "RS6", tankCapacity: 73),
            CarModel(name: "RS7", tankCapacity: 73),
            CarModel(name: "RS Q8", tankCapacity: 85)
        ]),
        CarMake(name: "Volkswagen", models: [
            CarModel(name: "Polo", tankCapacity: 40),
            CarModel(name: "Golf", tankCapacity: 50),
            CarModel(name: "Golf GTI", tankCapacity: 50),
            CarModel(name: "Golf R", tankCapacity: 50),
            CarModel(name: "Passat", tankCapacity: 66),
            CarModel(name: "Arteon", tankCapacity: 66),
            CarModel(name: "T-Cross", tankCapacity: 40),
            CarModel(name: "T-Roc", tankCapacity: 50),
            CarModel(name: "Tiguan", tankCapacity: 58),
            CarModel(name: "Touareg", tankCapacity: 90),
            CarModel(name: "ID.3", tankCapacity: 0), // Electric
            CarModel(name: "ID.4", tankCapacity: 0), // Electric
            CarModel(name: "ID.5", tankCapacity: 0), // Electric
            CarModel(name: "ID.Buzz", tankCapacity: 0), // Electric
            CarModel(name: "Transporter", tankCapacity: 70),
            CarModel(name: "Multivan", tankCapacity: 70),
            CarModel(name: "Amarok", tankCapacity: 80)
        ]),
        CarMake(name: "Porsche", models: [
            CarModel(name: "911", tankCapacity: 64),
            CarModel(name: "911 Turbo", tankCapacity: 67),
            CarModel(name: "718 Boxster", tankCapacity: 54),
            CarModel(name: "718 Cayman", tankCapacity: 54),
            CarModel(name: "Panamera", tankCapacity: 80),
            CarModel(name: "Cayenne", tankCapacity: 90),
            CarModel(name: "Cayenne Coupe", tankCapacity: 90),
            CarModel(name: "Macan", tankCapacity: 65),
            CarModel(name: "Taycan", tankCapacity: 0) // Electric
        ]),
        
        // British Brands
        CarMake(name: "Land Rover", models: [
            CarModel(name: "Range Rover", tankCapacity: 105),
            CarModel(name: "Range Rover Sport", tankCapacity: 90),
            CarModel(name: "Range Rover Velar", tankCapacity: 82),
            CarModel(name: "Range Rover Evoque", tankCapacity: 67),
            CarModel(name: "Defender 90", tankCapacity: 90),
            CarModel(name: "Defender 110", tankCapacity: 90),
            CarModel(name: "Defender 130", tankCapacity: 90),
            CarModel(name: "Discovery", tankCapacity: 90),
            CarModel(name: "Discovery Sport", tankCapacity: 70)
        ]),
        CarMake(name: "Jaguar", models: [
            CarModel(name: "XE", tankCapacity: 63),
            CarModel(name: "XF", tankCapacity: 74),
            CarModel(name: "F-Type", tankCapacity: 70),
            CarModel(name: "E-Pace", tankCapacity: 65),
            CarModel(name: "F-Pace", tankCapacity: 82),
            CarModel(name: "I-Pace", tankCapacity: 0) // Electric
        ]),
        CarMake(name: "Bentley", models: [
            CarModel(name: "Continental GT", tankCapacity: 90),
            CarModel(name: "Flying Spur", tankCapacity: 90),
            CarModel(name: "Bentayga", tankCapacity: 85)
        ]),
        CarMake(name: "Rolls-Royce", models: [
            CarModel(name: "Ghost", tankCapacity: 83),
            CarModel(name: "Phantom", tankCapacity: 100),
            CarModel(name: "Wraith", tankCapacity: 83),
            CarModel(name: "Dawn", tankCapacity: 83),
            CarModel(name: "Cullinan", tankCapacity: 100),
            CarModel(name: "Spectre", tankCapacity: 0) // Electric
        ]),
        CarMake(name: "Aston Martin", models: [
            CarModel(name: "Vantage", tankCapacity: 73),
            CarModel(name: "DB11", tankCapacity: 78),
            CarModel(name: "DB12", tankCapacity: 78),
            CarModel(name: "DBS", tankCapacity: 78),
            CarModel(name: "DBX", tankCapacity: 85)
        ]),
        CarMake(name: "McLaren", models: [
            CarModel(name: "GT", tankCapacity: 72),
            CarModel(name: "720S", tankCapacity: 72),
            CarModel(name: "765LT", tankCapacity: 72),
            CarModel(name: "Artura", tankCapacity: 66)
        ]),
        CarMake(name: "MINI", models: [
            CarModel(name: "Cooper", tankCapacity: 40),
            CarModel(name: "Cooper S", tankCapacity: 44),
            CarModel(name: "Clubman", tankCapacity: 48),
            CarModel(name: "Countryman", tankCapacity: 51),
            CarModel(name: "Electric", tankCapacity: 0) // Electric
        ]),
        
        // American Brands
        CarMake(name: "Ford", models: [
            CarModel(name: "Fiesta", tankCapacity: 42),
            CarModel(name: "Focus", tankCapacity: 52),
            CarModel(name: "Mustang", tankCapacity: 61),
            CarModel(name: "Mustang Mach-E", tankCapacity: 0), // Electric
            CarModel(name: "Explorer", tankCapacity: 87),
            CarModel(name: "Expedition", tankCapacity: 104),
            CarModel(name: "Edge", tankCapacity: 68),
            CarModel(name: "Bronco", tankCapacity: 70),
            CarModel(name: "Bronco Sport", tankCapacity: 54),
            CarModel(name: "Ranger", tankCapacity: 80),
            CarModel(name: "F-150", tankCapacity: 98),
            CarModel(name: "F-150 Raptor", tankCapacity: 136),
            CarModel(name: "Puma", tankCapacity: 42),
            CarModel(name: "Kuga", tankCapacity: 54)
        ]),
        CarMake(name: "Chevrolet", models: [
            CarModel(name: "Spark", tankCapacity: 35),
            CarModel(name: "Malibu", tankCapacity: 60),
            CarModel(name: "Camaro", tankCapacity: 72),
            CarModel(name: "Corvette", tankCapacity: 70),
            CarModel(name: "Trax", tankCapacity: 53),
            CarModel(name: "Equinox", tankCapacity: 60),
            CarModel(name: "Blazer", tankCapacity: 68),
            CarModel(name: "Traverse", tankCapacity: 83),
            CarModel(name: "Tahoe", tankCapacity: 91),
            CarModel(name: "Suburban", tankCapacity: 91),
            CarModel(name: "Silverado", tankCapacity: 98),
            CarModel(name: "Colorado", tankCapacity: 76)
        ]),
        CarMake(name: "GMC", models: [
            CarModel(name: "Terrain", tankCapacity: 60),
            CarModel(name: "Acadia", tankCapacity: 83),
            CarModel(name: "Yukon", tankCapacity: 91),
            CarModel(name: "Yukon XL", tankCapacity: 91),
            CarModel(name: "Sierra 1500", tankCapacity: 98),
            CarModel(name: "Canyon", tankCapacity: 76),
            CarModel(name: "Hummer EV", tankCapacity: 0) // Electric
        ]),
        CarMake(name: "Cadillac", models: [
            CarModel(name: "CT4", tankCapacity: 61),
            CarModel(name: "CT5", tankCapacity: 66),
            CarModel(name: "XT4", tankCapacity: 60),
            CarModel(name: "XT5", tankCapacity: 83),
            CarModel(name: "XT6", tankCapacity: 83),
            CarModel(name: "Escalade", tankCapacity: 91),
            CarModel(name: "Lyriq", tankCapacity: 0) // Electric
        ]),
        CarMake(name: "Jeep", models: [
            CarModel(name: "Renegade", tankCapacity: 48),
            CarModel(name: "Compass", tankCapacity: 51),
            CarModel(name: "Cherokee", tankCapacity: 60),
            CarModel(name: "Grand Cherokee", tankCapacity: 93),
            CarModel(name: "Grand Cherokee L", tankCapacity: 93),
            CarModel(name: "Wrangler", tankCapacity: 70),
            CarModel(name: "Gladiator", tankCapacity: 83),
            CarModel(name: "Wagoneer", tankCapacity: 93),
            CarModel(name: "Grand Wagoneer", tankCapacity: 93)
        ]),
        CarMake(name: "Dodge", models: [
            CarModel(name: "Charger", tankCapacity: 70),
            CarModel(name: "Challenger", tankCapacity: 70),
            CarModel(name: "Durango", tankCapacity: 93)
        ]),
        CarMake(name: "Chrysler", models: [
            CarModel(name: "300", tankCapacity: 68),
            CarModel(name: "Pacifica", tankCapacity: 72)
        ]),
        CarMake(name: "RAM", models: [
            CarModel(name: "1500", tankCapacity: 98),
            CarModel(name: "2500", tankCapacity: 117),
            CarModel(name: "3500", tankCapacity: 117)
        ]),
        CarMake(name: "Tesla", models: [
            CarModel(name: "Model 3", tankCapacity: 0), // Electric
            CarModel(name: "Model Y", tankCapacity: 0), // Electric
            CarModel(name: "Model S", tankCapacity: 0), // Electric
            CarModel(name: "Model X", tankCapacity: 0), // Electric
            CarModel(name: "Cybertruck", tankCapacity: 0) // Electric
        ]),
        CarMake(name: "Lincoln", models: [
            CarModel(name: "Corsair", tankCapacity: 60),
            CarModel(name: "Nautilus", tankCapacity: 68),
            CarModel(name: "Aviator", tankCapacity: 87),
            CarModel(name: "Navigator", tankCapacity: 104)
        ]),
        
        // Italian Brands
        CarMake(name: "Ferrari", models: [
            CarModel(name: "Roma", tankCapacity: 80),
            CarModel(name: "Portofino M", tankCapacity: 80),
            CarModel(name: "296 GTB", tankCapacity: 65),
            CarModel(name: "F8 Tributo", tankCapacity: 78),
            CarModel(name: "SF90 Stradale", tankCapacity: 68),
            CarModel(name: "812 Superfast", tankCapacity: 92),
            CarModel(name: "Purosangue", tankCapacity: 100)
        ]),
        CarMake(name: "Lamborghini", models: [
            CarModel(name: "Huracán", tankCapacity: 83),
            CarModel(name: "Huracán Tecnica", tankCapacity: 83),
            CarModel(name: "Urus", tankCapacity: 85),
            CarModel(name: "Revuelto", tankCapacity: 75)
        ]),
        CarMake(name: "Maserati", models: [
            CarModel(name: "Ghibli", tankCapacity: 80),
            CarModel(name: "Quattroporte", tankCapacity: 80),
            CarModel(name: "Levante", tankCapacity: 80),
            CarModel(name: "MC20", tankCapacity: 60),
            CarModel(name: "Grecale", tankCapacity: 64),
            CarModel(name: "GranTurismo", tankCapacity: 70)
        ]),
        CarMake(name: "Alfa Romeo", models: [
            CarModel(name: "Giulia", tankCapacity: 58),
            CarModel(name: "Stelvio", tankCapacity: 64),
            CarModel(name: "Tonale", tankCapacity: 54)
        ]),
        CarMake(name: "Fiat", models: [
            CarModel(name: "500", tankCapacity: 35),
            CarModel(name: "500X", tankCapacity: 48),
            CarModel(name: "Tipo", tankCapacity: 52),
            CarModel(name: "Panda", tankCapacity: 37),
            CarModel(name: "Egea", tankCapacity: 52),
            CarModel(name: "Doblo", tankCapacity: 60)
        ]),
        
        // French Brands
        CarMake(name: "Renault", models: [
            CarModel(name: "Clio", tankCapacity: 42),
            CarModel(name: "Megane", tankCapacity: 50),
            CarModel(name: "Talisman", tankCapacity: 60),
            CarModel(name: "Captur", tankCapacity: 48),
            CarModel(name: "Kadjar", tankCapacity: 55),
            CarModel(name: "Koleos", tankCapacity: 60),
            CarModel(name: "Austral", tankCapacity: 55),
            CarModel(name: "Arkana", tankCapacity: 50),
            CarModel(name: "Symbol", tankCapacity: 50),
            CarModel(name: "Taliant", tankCapacity: 50),
            CarModel(name: "Zoe", tankCapacity: 0), // Electric
            CarModel(name: "Scenic", tankCapacity: 0) // Electric
        ]),
        CarMake(name: "Peugeot", models: [
            CarModel(name: "208", tankCapacity: 44),
            CarModel(name: "308", tankCapacity: 53),
            CarModel(name: "408", tankCapacity: 52),
            CarModel(name: "508", tankCapacity: 62),
            CarModel(name: "2008", tankCapacity: 44),
            CarModel(name: "3008", tankCapacity: 53),
            CarModel(name: "5008", tankCapacity: 56),
            CarModel(name: "Rifter", tankCapacity: 50),
            CarModel(name: "Traveller", tankCapacity: 70),
            CarModel(name: "e-208", tankCapacity: 0), // Electric
            CarModel(name: "e-2008", tankCapacity: 0) // Electric
        ]),
        CarMake(name: "Citroën", models: [
            CarModel(name: "C3", tankCapacity: 45),
            CarModel(name: "C3 Aircross", tankCapacity: 45),
            CarModel(name: "C4", tankCapacity: 50),
            CarModel(name: "C4 Cactus", tankCapacity: 50),
            CarModel(name: "C5 Aircross", tankCapacity: 53),
            CarModel(name: "C5 X", tankCapacity: 55),
            CarModel(name: "Berlingo", tankCapacity: 50),
            CarModel(name: "SpaceTourer", tankCapacity: 70),
            CarModel(name: "e-C4", tankCapacity: 0) // Electric
        ]),
        CarMake(name: "DS", models: [
            CarModel(name: "DS 3 Crossback", tankCapacity: 44),
            CarModel(name: "DS 4", tankCapacity: 52),
            CarModel(name: "DS 7", tankCapacity: 55),
            CarModel(name: "DS 9", tankCapacity: 62)
        ]),
        
        // Swedish Brands
        CarMake(name: "Volvo", models: [
            CarModel(name: "S60", tankCapacity: 60),
            CarModel(name: "S90", tankCapacity: 71),
            CarModel(name: "V60", tankCapacity: 60),
            CarModel(name: "V90", tankCapacity: 71),
            CarModel(name: "XC40", tankCapacity: 54),
            CarModel(name: "XC60", tankCapacity: 71),
            CarModel(name: "XC90", tankCapacity: 71),
            CarModel(name: "C40 Recharge", tankCapacity: 0), // Electric
            CarModel(name: "EX30", tankCapacity: 0), // Electric
            CarModel(name: "EX90", tankCapacity: 0) // Electric
        ]),
        
        // Chinese Brands (Popular in Turkey/Qatar)
        CarMake(name: "Chery", models: [
            CarModel(name: "Tiggo 4 Pro", tankCapacity: 55),
            CarModel(name: "Tiggo 7 Pro", tankCapacity: 57),
            CarModel(name: "Tiggo 8 Pro", tankCapacity: 57),
            CarModel(name: "Arrizo 6", tankCapacity: 48),
            CarModel(name: "Omoda 5", tankCapacity: 55)
        ]),
        CarMake(name: "MG", models: [
            CarModel(name: "MG3", tankCapacity: 45),
            CarModel(name: "MG5", tankCapacity: 48),
            CarModel(name: "MG HS", tankCapacity: 55),
            CarModel(name: "MG ZS", tankCapacity: 45),
            CarModel(name: "MG RX5", tankCapacity: 55),
            CarModel(name: "MG RX8", tankCapacity: 73),
            CarModel(name: "MG4", tankCapacity: 0), // Electric
            CarModel(name: "Marvel R", tankCapacity: 0) // Electric
        ]),
        CarMake(name: "BYD", models: [
            CarModel(name: "Han", tankCapacity: 0), // Electric
            CarModel(name: "Tang", tankCapacity: 0), // Electric
            CarModel(name: "Song Plus", tankCapacity: 0), // Electric
            CarModel(name: "Atto 3", tankCapacity: 0), // Electric
            CarModel(name: "Seal", tankCapacity: 0), // Electric
            CarModel(name: "Dolphin", tankCapacity: 0) // Electric
        ]),
        CarMake(name: "Geely", models: [
            CarModel(name: "Emgrand", tankCapacity: 50),
            CarModel(name: "Coolray", tankCapacity: 50),
            CarModel(name: "Azkarra", tankCapacity: 60),
            CarModel(name: "Monjaro", tankCapacity: 60)
        ]),
        CarMake(name: "Haval", models: [
            CarModel(name: "Jolion", tankCapacity: 55),
            CarModel(name: "H6", tankCapacity: 65),
            CarModel(name: "H9", tankCapacity: 78)
        ]),
        CarMake(name: "GAC", models: [
            CarModel(name: "GS3", tankCapacity: 50),
            CarModel(name: "GS4", tankCapacity: 55),
            CarModel(name: "GS8", tankCapacity: 66),
            CarModel(name: "Empow", tankCapacity: 55)
        ]),
        
        // Turkish Brands
        CarMake(name: "TOGG", models: [
            CarModel(name: "T10X", tankCapacity: 0) // Electric
        ]),
        
        // Other Brands
        CarMake(name: "Škoda", models: [
            CarModel(name: "Fabia", tankCapacity: 40),
            CarModel(name: "Scala", tankCapacity: 50),
            CarModel(name: "Octavia", tankCapacity: 50),
            CarModel(name: "Superb", tankCapacity: 66),
            CarModel(name: "Kamiq", tankCapacity: 50),
            CarModel(name: "Karoq", tankCapacity: 55),
            CarModel(name: "Kodiaq", tankCapacity: 60),
            CarModel(name: "Enyaq", tankCapacity: 0) // Electric
        ]),
        CarMake(name: "SEAT", models: [
            CarModel(name: "Ibiza", tankCapacity: 40),
            CarModel(name: "Leon", tankCapacity: 50),
            CarModel(name: "Arona", tankCapacity: 40),
            CarModel(name: "Ateca", tankCapacity: 55),
            CarModel(name: "Tarraco", tankCapacity: 60)
        ]),
        CarMake(name: "CUPRA", models: [
            CarModel(name: "Formentor", tankCapacity: 55),
            CarModel(name: "Leon", tankCapacity: 50),
            CarModel(name: "Born", tankCapacity: 0), // Electric
            CarModel(name: "Tavascan", tankCapacity: 0) // Electric
        ]),
        CarMake(name: "Dacia", models: [
            CarModel(name: "Sandero", tankCapacity: 50),
            CarModel(name: "Logan", tankCapacity: 50),
            CarModel(name: "Duster", tankCapacity: 50),
            CarModel(name: "Jogger", tankCapacity: 50),
            CarModel(name: "Spring", tankCapacity: 0) // Electric
        ]),
        CarMake(name: "Opel", models: [
            CarModel(name: "Corsa", tankCapacity: 44),
            CarModel(name: "Astra", tankCapacity: 52),
            CarModel(name: "Insignia", tankCapacity: 60),
            CarModel(name: "Mokka", tankCapacity: 44),
            CarModel(name: "Crossland", tankCapacity: 44),
            CarModel(name: "Grandland", tankCapacity: 53),
            CarModel(name: "Combo", tankCapacity: 50)
        ]),
        CarMake(name: "Polestar", models: [
            CarModel(name: "Polestar 2", tankCapacity: 0), // Electric
            CarModel(name: "Polestar 3", tankCapacity: 0), // Electric
            CarModel(name: "Polestar 4", tankCapacity: 0) // Electric
        ]),
        CarMake(name: "Rivian", models: [
            CarModel(name: "R1T", tankCapacity: 0), // Electric
            CarModel(name: "R1S", tankCapacity: 0) // Electric
        ]),
        CarMake(name: "Lucid", models: [
            CarModel(name: "Air", tankCapacity: 0), // Electric
            CarModel(name: "Gravity", tankCapacity: 0) // Electric
        ])
    ]
    
    static func tankCapacity(make: String, model: String) -> Double? {
        makes.first { $0.name == make }?
            .models.first { $0.name == model }?
            .tankCapacity
    }
    
    static func models(for make: String) -> [CarModel] {
        makes.first { $0.name == make }?.models ?? []
    }
}
