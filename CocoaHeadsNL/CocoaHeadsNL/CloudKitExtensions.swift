//
//  ModelObjects.swift
//  CocoaHeadsNL
//
//  Created by Jeroen Leenarts on 27-03-15.
//  Copyright (c) 2016 Stichting CocoaheadsNL. All rights reserved.
//

import UIKit
import CoreSpotlight
import MobileCoreServices
import CloudKit
import CoreData

let indexQueue = OperationQueue()

var jobsIndexBackgroundTaskID = UIBackgroundTaskIdentifier.invalid
var meetupsIndexBackgroundTaskID = UIBackgroundTaskIdentifier.invalid

extension AffiliateLink {
//    let recordID: CKRecordID
//    let affiliateId: String?
//    let productCreator: String?
//    let productName: String?
//    let company: CKReference?

    static func affiliateLink(forRecord record: CKRecord, on context: NSManagedObjectContext) -> AffiliateLink {
        let newAffiliateLink = AffiliateLink(context: context)
                newAffiliateLink.recordID = record.recordID
                newAffiliateLink.affiliateId = record["affiliateId"] as? String
                newAffiliateLink.productName = record["productName"] as? String
                newAffiliateLink.productCreator = record["productCreator"] as? String
        //TODO:                newAffiliateLink.company = record["company"] as? CKReference

        return newAffiliateLink
    }
}

extension Company {

    static func company(forRecord record: CKRecord, on context: NSManagedObjectContext) -> Company {
        let newCompany = Company(context: context)
        newCompany.recordName = (record.recordID as CKRecord.ID?)?.recordName
        newCompany.name = record["name"] as? String
        newCompany.place = record["place"] as? String
        newCompany.streetAddress = record["streetAddress"] as? String
        newCompany.website = record["website"] as? String
        newCompany.zipCode = record["zipCode"] as? String
        newCompany.companyDescription = record["companyDescription"] as? String
        newCompany.emailAddress = record["emailAddress"] as? String
        newCompany.latitude = (record["location"] as? CLLocation)?.coordinate.latitude ?? 0.0
        newCompany.longitude = (record["location"] as? CLLocation)?.coordinate.longitude ?? 0.0

        if let logoAsset = record["logo"] as? CKAsset {
            newCompany.logo = try? NSData(contentsOf: logoAsset.fileURL!)
        }
        if let logoAsset = record["smallLogo"] as? CKAsset {
            newCompany.smallLogo = try? NSData(contentsOf: logoAsset.fileURL!)
        }

        return newCompany
    }

    var logoImage: UIImage {
        if let logo = self.logo, let image = UIImage(data: logo as Data) {
            return image
        } else {
            return UIImage(named: "CocoaHeadsNLLogo")!
        }
    }

    var smallLogoImage: UIImage {
        if let logo = self.smallLogo, let image = UIImage(data: logo as Data) {
            return image
        } else {
            return UIImage(named: "CocoaHeadsNLLogo")!
        }
    }
}

extension Contributor {
    static func contributor(forRecord record: CKRecord, on context: NSManagedObjectContext) -> Contributor {
        let contributor = Contributor(context: context)
        contributor.recordName = record.recordID.recordName
        contributor.name = record["name"] as? String ?? ""
        contributor.url = record["url"] as? String ?? ""
        contributor.avatarUrl = record["avatar_url"] as? String ?? ""
        contributor.contributorId = record["contributor_id"] as? Int64 ?? 0
        contributor.commitCount = Int32(record["commit_count"] as? Int ?? 0)
        return contributor
    }

}

extension Job {
    static func job(forRecord record: CKRecord, on context: NSManagedObjectContext) -> Job {
        let job = Job(context: context)

        job.recordName = record.recordID.recordName
        job.content = record["content"] as? String ?? ""
        job.date = record["date"] as? Date ?? Date()
        job.link = record["link"] as? String ?? ""
        job.title = record["title"] as? String ?? ""
        job.logoUrlString = record["logoUrl"] as? String

        if let logoURLString = job.logoUrlString, let logoURL = URL(string: logoURLString), let data = try? Data(contentsOf: logoURL) {
            job.logo = data as NSData
        }

        if let companyName = record["author"] as? String, companyName.count > 0 {
            job.companyName = companyName
        } else {
            job.companyName = nil
        }
        return job
    }

    var logoImage: UIImage {
        if let logo = self.logo, let image = UIImage(data: logo as Data) {
            return image
        } else {
            return UIImage(named: "CocoaHeadsNLLogo")!
        }
    }

    var searchableAttributeSet: CSSearchableItemAttributeSet {
        get {
            let attributeSet = CSSearchableItemAttributeSet(itemContentType: kUTTypeImage as String)
            attributeSet.title = title
            if let data = content?.data(using: String.Encoding.utf8) {
                do {
                    let jobDescriptionString = try NSAttributedString(data: data, options: [NSAttributedString.DocumentReadingOptionKey.documentType: NSAttributedString.DocumentType.html, NSAttributedString.DocumentReadingOptionKey.characterEncoding: String.Encoding.utf8], documentAttributes: nil)

                    attributeSet.contentDescription = jobDescriptionString.string
                } catch {
                    print("Stuff went crazy!")
                }
            }
            attributeSet.creator = "CocoaHeadsNL"
            attributeSet.thumbnailData = logoImage.pngData()

            return attributeSet
        }
    }

    class func index(_ jobs: [Job]) {
        if #available(iOS 9.0, *) {
            indexQueue.addOperation({ () -> Void in

                guard jobsIndexBackgroundTaskID == UIBackgroundTaskIdentifier.invalid else {
                    return
                }

                jobsIndexBackgroundTaskID = UIApplication.shared.beginBackgroundTask(expirationHandler: { () -> Void in
                    UIApplication.shared.endBackgroundTask(convertToUIBackgroundTaskIdentifier(jobsIndexBackgroundTaskID.rawValue))
                    jobsIndexBackgroundTaskID = UIBackgroundTaskIdentifier.invalid
                })

                var searchableItems = [CSSearchableItem]()
                for job in jobs {
                    let item = CSSearchableItem(uniqueIdentifier: "job:\(String(describing: job.recordName))", domainIdentifier: "job", attributeSet: job.searchableAttributeSet)
                    searchableItems.append(item)
                }

//                CSSearchableIndex.defaultSearchableIndex().deleteSearchableItemsWithDomainIdentifiers(["job"], completionHandler: { (error: NSError?) -> Void in
//                    if let error = error {
//                        print(error)
//                    }
//                })

                CSSearchableIndex.default().indexSearchableItems(searchableItems, completionHandler: { (error: Swift.Error?) -> Void in
                    if let error = error {
                        print(error)
                    }
                })

                UIApplication.shared.endBackgroundTask(convertToUIBackgroundTaskIdentifier(jobsIndexBackgroundTaskID.rawValue))
                jobsIndexBackgroundTaskID = UIBackgroundTaskIdentifier.invalid
            })
        }
    }
}

extension Meetup {

    static func meetup(forRecord record: CKRecord, on context: NSManagedObjectContext) -> Meetup {
        let meetup = Meetup(context: context)
        meetup.recordName = (record.recordID as CKRecord.ID?)?.recordName
        meetup.name = record["name"] as? String ?? ""
        meetup.meetupId = record["meetup_id"] as? String
        meetup.meetupDescription = record["meetup_description"] as? String ?? ""
        meetup.latitude = (record["geoLocation"] as? CLLocation)?.coordinate.latitude ?? 0.0
        meetup.longitude = (record["geoLocation"] as? CLLocation)?.coordinate.longitude ?? 0.0
        meetup.location = record["location"] as? String ?? ""
        meetup.locationName = record["locationName"] as? String ?? ""
        meetup.time = record["time"] as? Date
        meetup.nextEvent = record["nextEvent"] as? Bool ?? false

        meetup.year = Int32(Calendar.current.component(.year, from: meetup.time ?? Date()))

        meetup.duration = Int32(truncating: record.object(forKey: "duration") as? NSNumber ?? 0)
        meetup.rsvpLimit = Int32(truncating: record.object(forKey: "rsvp_limit") as? NSNumber ?? 0)
        meetup.yesRsvpCount = Int32(truncating: record.object(forKey: "yes_rsvp_count") as? NSNumber ?? 0)
        meetup.meetupUrl = record.object(forKey: "meetup_url") as? String

        if let logoAsset = record["logo"] as? CKAsset {
            meetup.logo = try? NSData(contentsOf: logoAsset.fileURL!)
        }
        if let logoAsset = record["smallLogo"] as? CKAsset {
            meetup.smallLogo = try? NSData(contentsOf: logoAsset.fileURL!)
        }

        return meetup
    }

    var logoImage: UIImage {
        if let logo = self.logo, let image = UIImage(data: logo as Data) {
            return image
        } else {
            return UIImage(named: "CocoaHeadsNLLogo")!
        }
    }

    var smallLogoImage: UIImage {
        if let logo = self.smallLogo, let image = UIImage(data: logo as Data) {
            return image
        } else {
            return UIImage(named: "CocoaHeadsNLLogo")!
        }
    }

    var isToday: Bool {
        guard let time = time else { return false }

        let today = dateOnlyFormatter.string(from: Date())
        return dateOnlyFormatter.string(from: time) == today
    }

    var isUpcoming: Bool {
        guard let time = time else { return false }

        return time.timeIntervalSinceNow > 0
    }

    @available(iOS 9.0, *)
    var searchableAttributeSet: CSSearchableItemAttributeSet {
        get {
            let attributeSet = CSSearchableItemAttributeSet(itemContentType: kUTTypeImage as String)
            attributeSet.title = name
            if let data = meetupDescription?.data(using: String.Encoding.utf8) {
                do {
                    let meetupDescriptionString = try NSAttributedString(data: data, options: [NSAttributedString.DocumentReadingOptionKey.documentType: NSAttributedString.DocumentType.html, NSAttributedString.DocumentReadingOptionKey.characterEncoding: String.Encoding.utf8], documentAttributes: nil)

                    attributeSet.contentDescription = meetupDescriptionString.string
                } catch {
                    print("Stuff went crazy!")
                }
            }
            attributeSet.creator = "CocoaHeadsNL"
            var keywords = ["CocoaHeadsNL"]
            if let locationName = locationName {
               keywords.append(locationName)
            }

            if let location = location {
                keywords.append(location)
            }

            attributeSet.keywords = keywords
            attributeSet.thumbnailData = smallLogoImage.pngData()

            return attributeSet
        }
    }

    class func index(_ meetups: [Meetup]) {
        if #available(iOS 9.0, *) {
            indexQueue.addOperation({ () -> Void in

                guard meetupsIndexBackgroundTaskID == UIBackgroundTaskIdentifier.invalid else {
                    return
                }

                meetupsIndexBackgroundTaskID = UIApplication.shared.beginBackgroundTask(expirationHandler: { () -> Void in
                    UIApplication.shared.endBackgroundTask(convertToUIBackgroundTaskIdentifier(jobsIndexBackgroundTaskID.rawValue))
                    meetupsIndexBackgroundTaskID = UIBackgroundTaskIdentifier.invalid
                })

                var searchableItems = [CSSearchableItem]()
                for meetup in meetups {
                    let item = CSSearchableItem(uniqueIdentifier: "meetup:\(String(describing: meetup.recordName))", domainIdentifier: "meetup", attributeSet: meetup.searchableAttributeSet)
                    searchableItems.append(item)
                }

//                CSSearchableIndex.defaultSearchableIndex().deleteSearchableItemsWithDomainIdentifiers(["meetup"], completionHandler: { (error: NSError?) -> Void in
//                    if let error = error {
//                        print(error)
//                    }
//                })

                CSSearchableIndex.default().indexSearchableItems(searchableItems, completionHandler: { (error: Swift.Error?) -> Void in
                    if let error = error {
                        print(error)
                    }
                })

                UIApplication.shared.endBackgroundTask(convertToUIBackgroundTaskIdentifier(jobsIndexBackgroundTaskID.rawValue))
                meetupsIndexBackgroundTaskID = UIBackgroundTaskIdentifier.invalid
            })
        }
    }
}

private let dateOnlyFormatter: DateFormatter = {
    let amsterdam = TimeZone(identifier: "Europe/Amsterdam")!
    let nl_NL = Locale(identifier: "nl-NL")

    let dateFormatter = DateFormatter()
    dateFormatter.dateFormat = "yyyy-MM-dd"
    dateFormatter.locale = nl_NL
    dateFormatter.timeZone = amsterdam

    return dateFormatter
}()

// Helper function inserted by Swift 4.2 migrator.
private func convertToUIBackgroundTaskIdentifier(_ input: Int) -> UIBackgroundTaskIdentifier {
	return UIBackgroundTaskIdentifier(rawValue: input)
}