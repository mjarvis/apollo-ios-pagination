import Apollo
import ApolloAPI

public class AnyGraphQLQueryPager<Model> {
  public typealias Output = Result<([Model], [[Model]], UpdateSource), Error>
  private let _fetch: (CachePolicy) -> Void
  private let _loadMore: (CachePolicy, (() -> Void)?) -> Bool
  private let _refetch: () -> Void
  private let _cancel: () -> Void
  private let _stream: AsyncStream<Output>
  
  public init<Pager: GraphQLQueryPager<InitialQuery, NextQuery>, InitialQuery, NextQuery>(
    pager: Pager,
    initialTransform: @escaping (InitialQuery.Data) -> [Model],
    nextPageTransform: @escaping (NextQuery.Data) -> [Model]
  ) {
    _fetch = pager.fetch
    _loadMore = pager.loadMore
    _refetch = pager.refetch
    _cancel = pager.cancel
    
    _stream = pager.subscribe().map { result in
      let returnValue: Output
      
      switch result {
      case let .success(value):
        let (initial, next, updateSource) = value
        let firstPage = initialTransform(initial)
        let nextPages = next.map { nextPageTransform($0) }
        returnValue = .success((firstPage, nextPages, updateSource))
      case let .failure(error):
        returnValue = .failure(error)
      }
      
      return returnValue
    }
  }
  
  public func subscribe() -> AsyncStream<Output> {
    return _stream
  }
  
  public func fetch(cachePolicy: CachePolicy = .returnCacheDataAndFetch) {
    _fetch(cachePolicy)
  }
  
  public func loadMore(cachePolicy: CachePolicy = .returnCacheDataAndFetch, completion: (() -> Void)? = nil) -> Bool {
    _loadMore(cachePolicy, completion)
  }
  
  public func refetch() {
    _refetch()
  }
  
  public func cancel() {
    _cancel()
  }
}

public extension GraphQLQueryPager {
  func eraseToAnyPager<T>(
    initialTransform: @escaping (InitialQuery.Data) -> [T],
    nextPageTransform: @escaping (PaginatedQuery.Data) -> [T]
  ) -> AnyGraphQLQueryPager<T> {
    .init(pager: self, initialTransform: initialTransform, nextPageTransform: nextPageTransform)
  }
}

extension AsyncStream {
  public func map<Transformed>(_ transform: @escaping (Self.Element) -> Transformed) -> AsyncStream<Transformed> {
    return AsyncStream<Transformed> { continuation in
      Task {
        for await element in self {
          continuation.yield(transform(element))
        }
        continuation.finish()
      }
    }
  }
}