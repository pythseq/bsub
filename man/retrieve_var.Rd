\name{retrieve_var}
\alias{retrieve_var}
\title{
Retrieve saved variable
}
\description{
Retrieve saved variable
}
\usage{
retrieve_var(name, output_dir = bsub_opt$output_dir, wait = 30)
}
\arguments{

  \item{name}{Job name}
  \item{output_dir}{The output dir set in \code{\link{bsub_chunk}}.}
  \item{wait}{Seconds to wait.}

}
\details{
It retrieve the saved variable in \code{\link{bsub_chunk}} when \code{save_rds = TRUE} is set.
}
\examples{
# There is no example
NULL

}
