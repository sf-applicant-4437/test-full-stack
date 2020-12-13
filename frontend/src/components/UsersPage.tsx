import React, { useEffect } from 'react';
import { gql, useApolloClient, useLazyQuery } from '@apollo/client';
import { QuerySearchUsersArgs, User, UserSearchResult } from '../api/types';

const SEARCH_USER_GQL = gql`
  query searchUser($name: String) {
    searchUsers(name: $name) {
      hasMore
      items {
        id
        name
        avatar
        dob
        createdAt
        updatedAt
      }
    }
  }
`;

const onUpdateUser = gql`
  subscription {
    onUpdateUser {
      id
      name
      dob
      description
      longitude
      latitude
      updatedAt
      createdAt
      avatar
      address
    }
  }
`;

const UsersPage: React.FC = () => {
  const [searchUserLazy, { data }] = useLazyQuery<UserSearchResult, QuerySearchUsersArgs>(SEARCH_USER_GQL);

  const apolloClient = useApolloClient();

  useEffect(() => {
    searchUserLazy({ variables: { name: 'p' } });
  }, []);

  useEffect(() => {
    const subscription = apolloClient
      .subscribe({
        fetchPolicy: 'no-cache',
        query: onUpdateUser,
      })
      .subscribe({
        next(value) {
          if (!value.data.onUpdateUser) return;

          const updated: User = value.data.onUpdateUser;
          console.log('Update received', updated);
        },
      });

    return () => {
      subscription.unsubscribe();
    };
  }, []);

  console.log('Users received!', data);
  return <div>UsersPage</div>;
};

export default UsersPage;