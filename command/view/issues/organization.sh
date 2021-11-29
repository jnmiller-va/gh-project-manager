#!/usr/bin/env bash
set -e

OWNER=$(gh repo view --json owner --jq .owner.login)
PROJECT_NUM=$1
LEGACY=$2

if [ "$LEGACY" == true ]; then
  QUERY="
    query(\$org: String!, \$projectNum: Int!, \$endCursor: String) {
      organization(login: \$org) {
        project(number: \$projectNum) {
          name
          body
          state
          columns(first:100) {
            nodes {
              name
              cards(first:100, after: \$endCursor) {
                pageInfo {
                  hasNextPage
                  endCursor
                }
                nodes {
                  content {
                    ... on Issue {
                      id
                      title
                    }
                  }
                }
              }
            }
          }
        }
      }
    }"

  exec gh api graphql -f query="${QUERY}" --paginate -F org="$OWNER" -F projectNum="$PROJECT_NUM" -q "[.data.organization.project.columns.nodes[] as \$columns | \$columns.cards.nodes[] | select(.content != null) | {id: .content.id, title: .content.title, status: \$columns.name}]"
else
   QUERY="
     query(\$org: String!, \$projectNum: Int!, \$endCursor: String) {
       organization(login: \$org) {
         projectNext(number: \$projectNum) {
           title
           fields(first:100) {
             nodes {
               id
               name
               settings
             }
           }
           items(first:100, after:\$endCursor ) {
             nodes {
               fieldValues(first: 100) {
                 nodes {
                   value
                   projectField {
                     id
                   }
                 }
               }
               content {
                 ... on Issue {
                   id
                   title
                 }
               }
             }
           }
         }
       }
     }"

  exec gh api graphql -f query="${QUERY}" --paginate -F org="$OWNER" -F projectNum="$PROJECT_NUM" -q ".data.organization.projectNext as \$project | \$project.fields.nodes[] | select(.name == \"Status\") | . as \$field | .settings | fromjson | . as \$settings | {id: \$field.id, name: \$field.name, settings: \$settings} as \$status | \$project.items.nodes as \$cards | \$cards | map({id: .content.id, title: .content.title, status: (.fieldValues.nodes[] | select(.projectField.id == \$status.id) as \$setting | \$settings.options[] | select(.id == \$setting.value)| .name) })"
fi
