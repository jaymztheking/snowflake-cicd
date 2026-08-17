terraform {
  # State is committed back into the repo by the apply workflow. There is no
  # locking beyond the GitHub Actions concurrency group that serializes applies.
  # This is a deliberate POC simplification — see README.md for the tradeoffs.
  backend "local" {
    path = "../state/terraform.tfstate"
  }
}
