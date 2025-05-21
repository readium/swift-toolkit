//
//  Copyright 2025 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Kingfisher
import ReadiumShared
import UIKit

class OPDSGroupTableViewCell: UITableViewCell {
    var group: Group?
    weak var opdsRootTableViewController: OPDSRootTableViewController?
    weak var collectionView: UICollectionView?

    var browsingState: FeedBrowsingState = .None

    static let iPadLayoutNumberPerRow: [ScreenOrientation: Int] = [.portrait: 4, .landscape: 5]
    static let iPhoneLayoutNumberPerRow: [ScreenOrientation: Int] = [.portrait: 3, .landscape: 4]

    lazy var layoutNumberPerRow: [UIUserInterfaceIdiom: [ScreenOrientation: Int]] = [
        .pad: OPDSGroupTableViewCell.iPadLayoutNumberPerRow,
        .phone: OPDSGroupTableViewCell.iPhoneLayoutNumberPerRow,
    ]

    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        collectionView?.setContentOffset(.zero, animated: false)
        collectionView?.reloadData()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        collectionView?.collectionViewLayout.invalidateLayout()
    }
}

extension OPDSGroupTableViewCell: UICollectionViewDataSource {
    // MARK: - Collection view data source

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        var count = 0

        if let group = group {
            if group.publications.count > 0 {
                count = group.publications.count
                browsingState = .Publication
            } else if group.navigation.count > 0 {
                count = group.navigation.count
                browsingState = .Navigation
            }
        }

        return count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        self.collectionView = collectionView

        if browsingState == .Publication {
            collectionView.register(UINib(nibName: "PublicationCollectionViewCell", bundle: nil),
                                    forCellWithReuseIdentifier: "publicationCollectionViewCell")

            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "publicationCollectionViewCell",
                                                          for: indexPath) as! PublicationCollectionViewCell

            cell.isAccessibilityElement = true
            cell.accessibilityHint = NSLocalizedString("opds_show_detail_view_a11y_hint", comment: "Accessibility hint for OPDS publication cell")

            if let publication = group?.publications[indexPath.row] {
                cell.accessibilityLabel = publication.metadata.title

                let titleTextView = OPDSPlaceholderListView(
                    frame: cell.frame,
                    title: publication.metadata.title,
                    author: publication.metadata.authors
                        .map(\.name)
                        .joined(separator: ", ")
                )

                let coverURL: URL? = publication.linkWithRel(.cover)?.url(relativeTo: publication.baseURL).url
                    ?? publication.images.first.flatMap { URL(string: $0.href) }

                if let coverURL = coverURL {
                    cell.coverImageView.kf.setImage(
                        with: coverURL,
                        placeholder: titleTextView,
                        options: [.transition(ImageTransition.fade(0.5))],
                        progressBlock: nil
                    ) { _ in }
                }

                cell.titleLabel.text = publication.metadata.title
                cell.authorLabel.text = publication.metadata.authors
                    .map(\.name)
                    .joined(separator: ", ")
            }

            return cell

        } else {
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "opdsNavigationCollectionViewCell",
                                                          for: indexPath) as! OPDSGroupCollectionViewCell

            if let navigation = group?.navigation[indexPath.row] {
                cell.accessibilityLabel = navigation.title

                cell.navigationTitleLabel.text = navigation.title
                if let count = navigation.properties.numberOfItems {
                    cell.navigationCountLabel.text = "\(count)"
                } else {
                    cell.navigationCountLabel.text = ""
                }
            }

            return cell
        }
    }
}

extension OPDSGroupTableViewCell: UICollectionViewDelegateFlowLayout {
    // MARK: - Collection view delegate

    func collectionView(_ collectionView: UICollectionView,
                        layout collectionViewLayout: UICollectionViewLayout,
                        sizeForItemAt indexPath: IndexPath) -> CGSize
    {
        if browsingState == .Publication {
            let idiom = { () -> UIUserInterfaceIdiom in
                let tempIdion = UIDevice.current.userInterfaceIdiom
                return (tempIdion != .pad) ? .phone : .pad // ignnore carplay and others
            }()

            guard let deviceLayoutNumberPerRow = layoutNumberPerRow[idiom] else { return CGSize(width: 0, height: 0) }
            guard let numberPerRow = deviceLayoutNumberPerRow[.current] else { return CGSize(width: 0, height: 0) }

            let minimumSpacing: CGFloat = 5.0
            let labelHeight: CGFloat = 50.0
            let coverRatio: CGFloat = 1.5

            let itemWidth = (collectionView.frame.width / CGFloat(numberPerRow)) - (CGFloat(minimumSpacing) * CGFloat(numberPerRow)) - minimumSpacing
            let itemHeight = (itemWidth * coverRatio) + labelHeight

            return CGSize(width: itemWidth, height: itemHeight)

        } else {
            return CGSize(width: 200, height: 50)
        }
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        if browsingState == .Publication {
            if let publication = group?.publications[indexPath.row] {
                let opdsPublicationInfoViewController: OPDSPublicationInfoViewController = OPDSFactory.shared.make(publication: publication)
                opdsRootTableViewController?.navigationController?.pushViewController(opdsPublicationInfoViewController, animated: true)
            }

        } else {
            if let href = group?.navigation[indexPath.row].href, let url = URL(string: href) {
                let newOPDSRootTableViewController: OPDSRootTableViewController = OPDSFactory.shared.make(feedURL: url, indexPath: nil)
                opdsRootTableViewController?.navigationController?.pushViewController(newOPDSRootTableViewController, animated: true)
            }
        }
    }
}
