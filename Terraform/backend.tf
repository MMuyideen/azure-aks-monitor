terraform {
  backend "azurerm" {
    resource_group_name  = "tf-week5-state-rg"
    storage_account_name = "tfpracticestorageweek5"
    container_name       = "tfpracticecontainer"
    key                  = "./terraform.tfstate"
  }
}
