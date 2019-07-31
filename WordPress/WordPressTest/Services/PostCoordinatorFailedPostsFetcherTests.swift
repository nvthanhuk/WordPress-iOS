
@testable import WordPress
import Nimble

class PostCoordinatorFailedPostsFetcherTests: XCTestCase {
    private var contextManager: TestContextManager!
    private var context: NSManagedObjectContext!

    private var fetcher: PostCoordinator.FailedPostsFetcher!

    override func setUp() {
        super.setUp()

        contextManager = TestContextManager()
        context = contextManager.newDerivedContext()
        fetcher = PostCoordinator.FailedPostsFetcher(context)
    }

    override func tearDown() {
        super.tearDown()
        fetcher = nil
        context = nil
        contextManager = nil
    }

    func testItOnlyReturnsLocalDrafts() {
        // Arrange
        let expectedPosts = [
            createPost(status: .draft),
            createPost(status: .draft),
            createPost(status: .draft),
            createPost(status: .publish)
        ]
        let unexpectedPosts = [
            createPost(status: .draft, hasRemote: true),
            createPost(status: .publish, hasRemote: true),
            createPost(status: .publishPrivate),
            createPost(status: .publishPrivate, hasRemote: true),
            createPost(status: .scheduled),
            createPost(status: .scheduled, hasRemote: true),
            createPost(status: .trash),
            createPost(status: .trash, hasRemote: true),
            // Local draft that we never attempted to upload so it never failed
            createPost(status: .draft, remoteStatus: .local)
        ]

        // Act
        let posts = fetcher.getPostsToRetrySync()

        // Assert
        expect(posts).to(haveCount(expectedPosts.count))
        expect(posts).to(contain(expectedPosts))
        expect(posts).notTo(contain(unexpectedPosts))
    }
}

private extension PostCoordinatorFailedPostsFetcherTests {
    func createPost(status: BasePost.Status,
                    remoteStatus: AbstractPostRemoteStatus = .failed,
                    hasRemote: Bool = false) -> Post {
        let post = Post(context: context)
        post.status = status
        post.remoteStatus = remoteStatus

        if hasRemote {
            post.postID = NSNumber(value: Int.random(in: 1...Int.max))
        }

        return post
    }
}

private extension PostCoordinator.FailedPostsFetcher {
    func getPostsToRetrySync() -> [AbstractPost] {
        var result = [AbstractPost]()
        waitUntil(timeout: 5) { done in
            self.getPostsToRetry { posts in
                result = posts
                done()
            }
        }
        return result
    }
}

