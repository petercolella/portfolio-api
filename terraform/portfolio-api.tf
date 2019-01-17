provider "aws" {
}

variable "accountId" {}

resource "aws_iam_role" "portfolio-api-role" {
  name = "portfolio-api-role"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

resource "aws_iam_policy" "portfolio-api-s3-policy" {
    name        = "portfolio-api-s3-policy"
    description = "portfolio-api-s3-policy"
    policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "0",
            "Effect": "Allow",
            "Action": [
                "s3:ListBucket",
                "s3:GetBucketLocation"
            ],
            "Resource": "arn:aws:s3:::portfolio-test-example"
        },
        {
            "Sid": "1",
            "Effect": "Allow",
            "Action": "s3:*",
            "Resource": "arn:aws:s3:::portfolio-test-example/*"
        }
    ]
}
EOF
}

resource "aws_iam_policy" "portfolio-api-dynamodb-tables-policy" {
    name        = "portfolio-api-dynamodb-policy"
    description = "grants access to all tables prefixed by portfolio-api_*"
    policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "dynamodb:BatchGetItem",
                "dynamodb:BatchWriteItem",
                "dynamodb:DeleteItem",
                "dynamodb:GetItem",
                "dynamodb:PutItem",
                "dynamodb:Query",
                "dynamodb:UpdateItem"
            ],
            "Resource": [
                "arn:aws:dynamodb:*:*:table/article_*"
            ]
        }
    ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "portfolio-api-role-policy-attach-1" {
  role = "${aws_iam_role.portfolio-api-role.name}"
  policy_arn = "${aws_iam_policy.portfolio-api-s3-policy.arn}"
}

resource "aws_iam_role_policy_attachment" "portfolio-api-role-policy-attach-2" {
  role = "${aws_iam_role.portfolio-api-role.name}"
  policy_arn = "arn:aws:iam::aws:policy/AWSLambdaExecute"
}

resource "aws_iam_role_policy_attachment" "portfolio-api-role-policy-attach-4" {
  role = "${aws_iam_role.portfolio-api-role.name}"
  policy_arn = "${aws_iam_policy.portfolio-api-dynamodb-tables-policy.arn}"
}

resource "aws_api_gateway_rest_api" "portfolio-api" {
  name        = "portfolio-api"
  description = "Golang Serverless Application Example"
}

resource "aws_api_gateway_resource" "resource" {
  path_part   = "resource"
  parent_id   = "${aws_api_gateway_rest_api.portfolio-api.root_resource_id}"
  rest_api_id = "${aws_api_gateway_rest_api.portfolio-api.id}"
}

resource "aws_api_gateway_method" "method" {
  rest_api_id   = "${aws_api_gateway_rest_api.portfolio-api.id}"
  resource_id   = "${aws_api_gateway_resource.resource.id}"
  http_method   = "GET"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "integration" {
  rest_api_id             = "${aws_api_gateway_rest_api.portfolio-api.id}"
  resource_id             = "${aws_api_gateway_resource.resource.id}"
  http_method             = "${aws_api_gateway_method.method.http_method}"
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = "arn:aws:apigateway:us-east-1:lambda:path/2015-03-31/functions/${aws_lambda_function.portfolio-api.arn}/invocations"
}

resource "aws_lambda_function" "portfolio-api" {
  filename         = "../../../../build/portfolio-api.zip"
  source_code_hash = "${base64sha256(file("../../../../build/portfolio-api.zip"))}"
  function_name    = "portfolio-api"
  role             = "${aws_iam_role.portfolio-api-role.arn}"
  handler          = "portfolio-api"
  runtime          = "go1.x"
  publish          = true
  memory_size      = 512
  timeout          = 30

  tracing_config {
    mode = "Active"
  }
}

resource "aws_lambda_permission" "portfolio-api-bucket" {
  statement_id  = "1"
  action        = "lambda:InvokeFunction"
  function_name = "${aws_lambda_function.portfolio-api.arn}"
  principal     = "s3.amazonaws.com"
  source_arn    = "arn:aws:s3:::portfolio-test-example"
}

resource "aws_lambda_permission" "apigw" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = "${aws_lambda_function.portfolio-api.arn}"
  principal     = "apigateway.amazonaws.com"

  source_arn = "arn:aws:execute-api:us-east-1:${var.accountId}:${aws_api_gateway_rest_api.portfolio-api.id}/*/${aws_api_gateway_method.method.http_method} ${aws_api_gateway_resource.resource.path}"
}

