setClassUnion('CharacterOrNull', c("character", "NULL"))


#' Class Scroller
#' 
#' Scroll through large result sets
#' 
#' This class is not meant to be called by an end 
#' user. Instead, start with a Searcher object and 
#' then call \code{searcher$scroll()}.
#' 
#' 
#' 
#' @export
Scroller = R6Class(
  "Scroller",
  list(
    scroll_id = NULL,
    scroll    = NULL,
    .last     = NULL,
    search    = NULL,
    progress  = NULL,
    
    initialize = function(search) {
      self$scroll_id <- NULL
      self$search <- search
      self$progress <- interactive()
      self$.last  <- FALSE
      self$scroll = "1m"
    },
    
    has_next = function() {
      if(.last) return(FALSE)
    },
    
    chunk = function() {
      if(is.null(self$scroll_id)) {
        res = self$search$results()
      }
      else if(!is.null(self$scroll_id)) {
        res = .sra_scroll(scroll_id = self$scroll_id, scroll = self$scroll)
      }
      self$scroll_id <- attr(res, 'scroll_id')
      if(nrow(res)==0) {
        self$.last <- TRUE
        return(NULL)
      }
      return(res)
    },
    
    collate = function() {
      self$scroll_id <- NULL
      count = self$search$count()
      size  = self$search$size
      iters = ceiling(count/size)
      if(self$progress) {
        pb = progress::progress_bar$new(
          format = " downloading [:bar] :percent eta: :eta",
          total = iters, clear = FALSE, width= 60)
      }
      l = lapply(seq_len(iters), function(n) {
        if(self$progress) pb$tick()
        return(self$chunk())
      })
      dplyr::bind_rows(l)
    }
    
  )
)

OidxSearch = setRefClass("OidxSearch",
            fields = list(q = 'CharacterOrNull',
                          entity='character',
                          size = "integer",
                          start = "integer",
                          return_fields = "CharacterOrNull"),
            methods = list(
              initialize = function(q='*', entity='full', size = 100L, start = 0L, return_fields=NULL) {
                "Initialize a new OidxSearch object."
                entity <<- entity
                q      <<- q
                size   <<- size
                start  <<- start
                return_fields <<- return_fields
              },
              count = function() {
                "Return a simple count of records that meet the search criteria"
                path = paste0('/search/',.self$entity)
                return(attr(.sra_get_search_function(path, q = .self$q, size = 1, start = 0, fields=return_fields),"count"))
              },
              results = function() {
                path = paste0('/search/',entity)
                return(.sra_get_search_function(path, q = q, size = size, 
                                         start = start, fields=return_fields))
              },
              
              scroll = function() {
                return(Scroller$new(.self$copy()))
              }
            ))


Omicidx = setRefClass("Omicidx", methods = list(
  search = function(q='*', entity = 'full', start=0L, size=100L, return_fields = NULL) {
    "Build a new search of the Omicidx API"
    return(OidxSearch$new(q, entity, start = start, 
                          size = size, return_fields = return_fields))
  }
))