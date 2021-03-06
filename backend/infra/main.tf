terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.20"
    }
  }
}

provider "aws" {
  profile = "default"
  region  = var.region
}

data "aws_region" "current"{}
data "aws_caller_identity" "current"{}

module "appsync" {
  source  = "terraform-aws-modules/appsync/aws"
  version = "0.8.0"
  name = "${var.appName}-appsync"

  schema = file("graphql/schema.graphql")

  api_keys = {
    default = null #keys will last 7 days.
  }

  datasources = {
    superformula_dynamodb4437 = {
      type       = "AMAZON_DYNAMODB"
      table_name = aws_dynamodb_table.users_table.name
      region     = var.region
    }

    superformula_google_address_api = {
      type         = "AWS_LAMBDA"
      function_arn = aws_lambda_function.google_api_getAddress_lambda.arn
    }

    superformula_google_coordinates_api = {
      type         = "AWS_LAMBDA"
      function_arn = aws_lambda_function.google_api_getCoordinates_lambda.arn
    }
  }

  resolvers = {
    "Query.getAllUsers" = {
      data_source       = "superformula_dynamodb4437"
      request_template  = file("graphql/queries/listUsers-request-map.vtl")
      response_template = file("graphql/queries/listUsers-response-map.vtl")
    }

    "Query.getUserById" = {
      data_source       = "superformula_dynamodb4437"
      request_template  = file("graphql/queries/getUserById-request-map.vtl")
      response_template = file("graphql/queries/getUserById-response-map.vtl")
    }

    "Query.getAddresses" = {
      data_source       = "superformula_google_address_api"
      request_template  = file("graphql/queries/getAddresses-request-map.vtl")
      response_template = file("graphql/queries/getAddresses-response-map.vtl")
    }

    "Query.getCoordinates" = {
      data_source       = "superformula_google_coordinates_api"
      request_template  = file("graphql/queries/getCoordinates-request-map.vtl")
      response_template = file("graphql/queries/getCoordinates-response-map.vtl")
    }

    "Mutation.createUser" = {
      data_source       = "superformula_dynamodb4437"
      request_template  = file("graphql/mutations/createUser-request-map.vtl")
      response_template = file("graphql/mutations/createUser-response-map.vtl")
    }

    "Mutation.deleteUser" = {
      data_source       = "superformula_dynamodb4437"
      request_template  = file("graphql/mutations/deleteUser-request-map.vtl")
      response_template = file("graphql/mutations/deleteUser-response-map.vtl")
    }

    "Mutation.updateUser" = {
      data_source       = "superformula_dynamodb4437"
      request_template  = file("graphql/mutations/updateUser-request-map.vtl")
      response_template = file("graphql/mutations/updateUser-response-map.vtl")
    }
  }
}


// Manually create the elastic search data source and resolvers because the TF module above can't properly create them

resource "aws_iam_role" "elastic_datasource_role" {
  name = "${var.appName}_elasticserch_datasource"
  assume_role_policy = <<EOL
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "appsync.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOL
}

resource "aws_iam_role_policy_attachment" "add_elastic_access-appsync_datasource" {
  policy_arn = aws_iam_policy.elastic_search_access.arn
  role = aws_iam_role.elastic_datasource_role.name
}

resource "aws_appsync_datasource" "elastic_search_datasource" {
  api_id = module.appsync.this_appsync_graphql_api_id
  name = "elasticsearch1"
  type = "AMAZON_ELASTICSEARCH"
  service_role_arn = aws_iam_role.elastic_datasource_role.arn

  elasticsearch_config {
    endpoint = "https://${aws_elasticsearch_domain.terraform-appsync-elasticsearch.endpoint}"
    region = var.region
  }
}

resource "aws_appsync_resolver" "elastic_search_resolver" {
  api_id = module.appsync.this_appsync_graphql_api_id
  field = "searchUsers"
  request_template = file("graphql/queries/searchUser-request-map.vtl")
  response_template = file("graphql/queries/searchUser-response-map.vtl")
  type = "Query"
  data_source = aws_appsync_datasource.elastic_search_datasource.name
}

