:- module(
  ckan,
  [
    current_package_list_with_resources/4, % +Options:list(nvpair)
                                           % +Limit:positive_integer
                                           % +Offset:positive_integer
                                           % -Resources:list
    group_list/6, % +Options:list(nvpair)
                  % +AllFields:boolean
                  % +Field:oneof([name,packages])
                  % +Groups:list(atom)
                  % +Order:atom
                  % -Groups:list(atom)
    group_list_authz/4, % +Options:list(nvpair)
                        % +AmMember:boolean
                        % +AvailableOnly:boolean
                        % -Groups:list(compound)
    group_revision_list/3, % +Options:list(nvpair),
                           % +NameOrId:atom,
                           % -Revisions:list(compound)
    license_list/2, % +Options:list(nvpair)
                    % -Licenses:list(compound)
    member_list/5, % +Options:list(nvpair)
                   % +Capacity:atom
                   % +IdOrName:atom
                   % +ObjectType:atom
                   % -Triples:list(triple(atom,atom,atom))
    organization_list/6, % +Options:list(nvpair)
                         % +AllFields:boolean
                         % +Field:oneof([name,packages])
                         % +Order:atom
                         % +OrganizationsFilter:list(atom)
                         % -Organizations:list(atom)
    organization_list_for_user/3, % +Options:list(nvpair),
                                  % +Permission:atom,
                                  % -Organizations:list(compound)
    package_list/4, % +Options:list(nvpair)
                    % +Limit:integer
                    % +Offset:integer
                    % -Packages:list(atom)
    package_revision_list/3, % +Options:list(nvpair)
                             % +Package:atom
                             % -Revisions:list(compound)
    package_show/3, % +Options:list(nvpair)
                    % +IdOrName:atom
                    % -Package:compound
    related_list/7, % +Options:list(nvpair)
                    % ?Dataset:compound
                    % ?Featured:boolean
                    % ?IdOrName:atom
                    % ?Sort:oneof([created_asc,created_desc,view_count_asc,view_count_desc])
                    % ?TypeFilter:atom
                    % -Related:list(compound)
    related_show/3, % +Options:list(nvpair)
                    % +Id:atom
                    % -Out:compound
    revision_list/2, % +Options:list(nvpair)
                     % -Revisions:list(atom)
    site_read/1 % +Options:list(nvpair)
  ]
).

/** <module> CKAN

Querying the CKAN API.

The following options are API-wide supported:
  * =|deprecated(Deprecated:boolean)|=
    Use the deprecated API.
  * =|paginated(Paginated:boolean)|=
    Use pagination in order to retrieve all results.

The following depretations (v.2.0.3) are supported:
  * For: current_package_list_with_resources/4
    Use parameter name `page` i.o. `offset`.
  * For: license_list/2
    Use licence_list/2 instead.

--

@author Wouter Beek
@see http://docs.ckan.org/en/latest/api.html
@tbd The CKAN API uses `True` and `False` for boolean values.
@tbd The JSON `null` value is not replaced with a given default value.
@version 2013/11-2014/01
*/

:- use_module(generics(meta_ext)).
:- use_module(generics(option_ext)).
:- use_module(generics(uri_ext)).
:- use_module(library(apply)).
:- use_module(library(debug)).
:- use_module(library(http/http_open)).
:- use_module(library(http/json)).
:- use_module(library(http/json_convert)).
:- use_module(library(lists)).
:- use_module(library(option)).
:- use_module(library(uri)).
:- use_module(server(api_keys)).
:- use_module(standards(json_ext)).

% `Predicate:atom-Type:atom-Optional:boolean`
rdf_legend(
  license,
  [
    domain_content-boolean-false,
    domain_data-boolean-false,
    domain_software:boolean-false,
    family:atom:false,
    id:atom:true,
    is_okd_compliant:boolean:false,
    is_generic:boolean:flase,
    is_osi_compliant:boolean:false,
    maintainer:atom:false,
    status:atom:true,
    title:atom:true,
    url:atom:false
  ]
).
:- json_object license(
  domain_content, % boolean
  domain_data, % boolean
  domain_software, % boolean
  family, % can be null
  id:atom,
  is_okd_compliant, % boolean
  is_generic, % boolean
  is_osi_compliant, % boolean
  maintainer, % can be null
  status:atom,
  title:atom,
  url % can be null
).
:- json_object organization(
  approval_status:atom,
  description, % `atom` or `@(null)`
  display_name:atom,
  id:atom,
  image_url, % `atom` or `@(null)`
  is_organization:boolean,
  name:atom,
  packages:integer,
  revision_id:atom,
  state:atom,
  title:atom,
  type:atom
).
:- json_object package(
  author, % `atom` or `@(null)`
  author_email, % `atom` or `@(null)`
  id:atom,
  license_id, % `atom` or `@(null)`
  license_title, % `atom` or `@(null)`
  maintainer, % `atom` or `@(null)`
  maintainer_email, % `atom` or `@(null)`
  num_tags:integer,
  private:boolean,
  metadata_created:atom,
  metadata_modified:atom,
  relationships_as_object:list,
  resources:list(resource/22),
  state:atom,
  type:atom,
  version % `atom` or `@(null)`
).
:- json_object resource(
  cache_last_updated,
  cache_url,
  created:atom,
  description:atom,
  format:atom,
  hash:atom,
  id:atom,
  last_modified,
  mimetype,
  mimetype_inner, % `atom` or `@(null)`
  name, % `atom` or `@(null)`
  position:integer,
  resource_group_id:atom,
  resource_type, % `atom` or `@(null)`
  revision_id:atom,
  revision_timestamp:atom,
  size,
  state:atom,
  tracking_summary:tracking_summary/2,
  url:atom,
  webstore_last_updated, % `atom` or `@(null)`
  webstore_url % `atom` or `@(null)`
).
:- json_object revision(
  approved_timestamp, % `atom` or `@(null)`
  author, % `atom` or `@(null)`
  id:atom,
  message, % `atom` or `@(null)`
  timestamp:atom
).
:- json_object tracking_summary(
  total:integer,
  recent:integer
).

:- debug(ckan).



%! current_package_list_with_resources(
%!   +Options:list(nvpair),
%!   +Limit:positive_integer,
%!   +Offset:positive_integer,
%!   -Packages:list(atom)
%! ) is det.
% Return a list of the site's datasets (packages) and their resources.
%
% @arg Options
% @arg Limit If given, the list of datasets will be broken into
%      pages of at most `limit` datasets per page and only one page
%      will be returned at a time.
% @arg Offset If `limit` is given, the offset to start returning packages
%      from.
% @arg PackagesAndResources

current_package_list_with_resources(O1, Limit1, Offset1, PackagesAndResources):-
  select_option(paginated(true), O1, O2), !,
  default(Limit1, 10, Limit2),
  default(Offset1, 1, Offset2),
  paginated_current_package_list_with_resources(
    O2,
    Limit2,
    Offset2,
    PackagesAndResources
  ).
current_package_list_with_resources(O1, Limit, Offset, PackagesAndResources):-
  process_limit_offset(O1, Limit, Offset, P1),
  ckan(O1, current_package_list_with_resources, P1, PackagesAndResources).

paginated_current_package_list_with_resources(O1, Limit, Offset1, L3):-
  current_package_list_with_resources(O1, Limit, Offset1, L1), !,
  debug(ckan, 'Offset: ~d\n~w\n\n\n', [Offset1,L1]),
  Offset2 is Offset1 + Limit,
  paginated_current_package_list_with_resources(O1, Limit, Offset2, L2),
  append(L1, L2, L3).
paginated_current_package_list_with_resources(_, _, _, []).


%! group_list(
%!   +Options:list(nvpair),
%!   +AllFields:boolean,
%!   +Field:oneof([name,packages]),
%!   +Groups:list(atom),
%!   +Order:atom,
%!   -Groups:list(atom)
%! ) is det.
% Return a list of the names of the site's groups.
%
% @arg Options
% @arg AllFields Whether full group dictionaries should be returned
%      instead of just names.
%      Default: `false`.
% @arg Field Sorting of the search results based on this field.
%      The allowed fields are `name` and `packages`.
%      Default: `name`.
% @arg Groups A list of names of the groups to return, if given
%      only groups whose names are in this list will be returned.
%      Optional.
% @arg Order The sort-order used.
%      Default: `asc`
% @arg Groups A list of the atomic names of the site's groups.

group_list(O1, AllFields1, Field, Groups, Order, Groups):-
  default(AllFields1, false, AllFields2),
  json_boolean(AllFields2, AllFields3),
  process_field_order_sort(Field, Order, Sort),
  add_option([all_fields=AllFields3,sort=Sort], groups, Groups, P1),
  ckan(O1, group_list, P1, Groups).


%! group_list_authz(
%!   +Options:list(nvpair),
%!   +AmMember:boolean,
%!   +AvailableOnly:boolean,
%!   -Groups:list(compound)
%! ) is det.
% Return the list of groups that the user is authorized to edit.
%
% @arg Options
% @arg AmMember If `true` return only the groups the logged-in user
%      is a member of, otherwise return all groups that the user
%      is authorized to edit (for example, sysadmin users
%      are authorized to edit all groups) (optional, default: `false`).
% @arg AvailableOnly Remove the existing groups in the package
%      (optional, default: `false`).
% @arg Groups List of dictized groups that the user is authorized to edit.

group_list_authz(O1, AmMember1, AvailableOnly1, Groups):-
  default(AvailableOnly1, false, AvailableOnly2),
  json_boolean(AvailableOnly2, AvailableOnly3),
  default(AmMember1, false, AmMember2),
  json_boolean(AmMember2, AmMember3),
  ckan(
    O1,
    group_list_authz,
    [am_member=AmMember3,available_only=AvailableOnly3],
    Groups
  ).


%! group_revision_list(
%!   +Options:list(nvpair),
%!   +NameOrId:atom,
%!   -Revisions:list(compound)
%! ) is det.
% Return a group's revisions.
%
% @arg Options
% @arg NameOrId The name or id of the group.
% @arg Revisions List of dictionaries.

group_revision_list(O1, NameOrId, Revisions):-
  ckan(O1, group_revision_list, [id=NameOrId], Revisions).


%! license_list(+Options:list(nvpair), -Licenses:list(compound)) is det.
% Return the list of licenses available for datasets on the site.
%
% @arg Options
% @arg Licenses List of dictionaries.

license_list(O1, Licenses):-
  (
    option(deprecated(true), O1)
  ->
    FunctionName = licence_list
  ;
    FunctionName = license_list
  ),
  
  ckan(O1, FunctionName, [], JSON),
  json_to_prolog(JSON, Licenses).


%! member_list(
%!   +Options:list(nvpair),
%!   +Capacity:atom,
%!   +IdOrName:atom,
%!   +ObjectType:atom,
%!   -Triples:list(triple(atom,atom,atom))
%! ) is det.
% Return the members of a group.
%
% The user must have permission to ‘get’ the group.
%
% @arg Capacity Restrict the members returned to those with a given capacity,
%      e.g. `member`, `editor`, `admin`, `public`, `private`
%      (optional, default: `None`)
% @arg IdOrName The id or name of the group.
% @arg ObjectType Restrict the members returned to those of a given type,
%      e.g. `user` or `package` (optional, default: `None`).
% @arg Triples A list of <id,type,capacity>-triples.
%
% @throw ckan.logic.NotFound If the group does not exist.

member_list(O1, Capacity, IdOrName, ObjectType, Triples):-
  P1 = [id=IdOrName],
  add_option(P1, capacity, Capacity, P2),
  add_option(P2, object_type, ObjectType, P3),
  ckan(O1, member_list, P3, Triples).


%! organization_list(
%!   +Options:list(nvpair),
%!   +AllFields:boolean,
%!   +Field:oneof([name,packages]),
%!   +Order:atom,
%!   +OrganizationsFilter:list(atom),
%!   -Organizations:list(atom)
%! ) is det.
% Return a list of the names of the site’s organizations.
%
% @arg AllFields Return full group dictionaries instead of just names
%      (optional, default: `false`).
% @arg Field Sorting of the search results based on this field.
%      The allowed fields are `name` and `packages`.
%      Default: `name`.
% @arg Order The sort-order used.
%      Default: `asc`
% @arg OrganizationsFilter A list of names of the groups to return,
%      if given only groups whose names are in this list
%      will be returned (optional).
% @arg Organizations A list of organization names.

organization_list(
  O1,
  AllFields1,
  Field,
  Order,
  OrganizationsFilter,
  Organizations
):-
  default(AllFields1, false, AllFields2),
  json_boolean(AllFields2, AllFields3),
  process_field_order_sort(Field, Order, Sort),
  add_option(
    [all_fields=AllFields3,sort=Sort],
    organizations,
    OrganizationsFilter,
    P1
  ),
  ckan(O1, organization_list, P1, JSON),
  json_to_prolog(JSON, Organizations).


%! organization_list_for_user(
%!   +Options:list(nvpair),
%!   +Permission:atom,
%!   -Organizations:list(compound)
%! ) is det.
% Return the list of organizations that the user is a member of.
%
% @arg Options
% @arg Permission The permission the user has against
%      the returned organizations (optional, default: `edit_group`).
% @arg Organizations List of dictized organizations
%      that the user is authorized to edit.

organization_list_for_user(O1, Permission1, Organizations):-
  default(Permission1, edit_group, Permission2),
  ckan(
    O1,
    organization_list_for_user,
    [permission=Permission2],
    Organizations
  ).


%! package_list(
%!   +Options:list(nvpair),
%!   +Limit:integer,
%!   +Offset:integer,
%!   -Packages:list(atom)
%! ) is det.
% Return a list of the names of the site's datasets (packages).
%
% @arg Options
% @arg Limit If given, the list of datasets will be broken into pages
%      of at most `Limit` datasets per page and only one page
%      will be returned at a time (optional).
% @arg Offset If `limit` is given, the offset to start returning packages
%      from.
% @arg Packages A list of atomic package/dataset names.
%      The list is sorted most-recently-modified first.

package_list(O1, Limit, Offset, Packages):-
  process_limit_offset(O1, Limit, Offset, P2),
  ckan(O1, package_list, P2, Packages).


%! package_revision_list(
%!   +Options:list(nvpair),
%!   +Package:atom,
%!   -Revisions:list(compound)
%! ) is det.
% Return a dataset (package)'s revisions as a list of dictionaries.
%
% @arg Options
% @arg Package The id or name of the dataset.
% @arg Revisions A list of revision terms.

package_revision_list(O1, Package, Revisions):-
  ckan(O1, package_revision_list, [id(Package)], JSON),
  json_to_prolog(JSON, Revisions).


%! package_show(
%!   +Options:list(nvpair),
%!   +IdOrName:atom,
%!   -Package:compound
%! ) is det.

package_show(O1, IdOrName, Package):-
  ckan(O1, package_show, [id(IdOrName)], JSON),
  json_to_prolog(JSON, Package).


%! related_list(
%!   +Options:list(nvpair),
%!   +Dataset:compound,
%!   +Featured:boolean,
%!   +IdOrName:atom,
%!   +Sort:oneof([created_asc,created_desc,view_count_asc,view_count_desc]),
%!   +TypeFilter:atom,
%!   -Related:list(compound)
%! ) is det.
% Return a dataset's related items.
%
% Either the `IdOrName` or the `Dataset` parameter must be given.
%
% @arg Options
% @arg Dataset Dataset dictionary of the dataset (optional).
% @arg Featured Whether or not to restrict the results
%      to only featured related items (optional, default: `false`)
% @arg IdOrName Id or name of the dataset (optional).
% @arg TypeFilter The type of related item to show
%      (optional, default: None, showing all items).
% @arg Sort The order to sort the related items in.
%      Possible values are `view_count_asc`, `view_count_desc`,
%      `created_asc` or `created_desc` (optional).
% @arg Related A list of dictionaries

related_list(O1, Dataset, Featured1, IdOrName, TypeFilter, Sort, Related):-
  default(Featured1, false, Featured2),
  json_boolean(Featured2, Featured3),

  % Either `dataset` or `id`.
  \+ maplist(nonvar, [Dataset,IdOrName]),
  \+ maplist(var, [Dataset,IdOrName]),

  add_option([featured=Featured3], dataset, Dataset, P2),
  add_option(P2, id, IdOrName, P3),

  % Optional `type_filter`
  add_option(P3, type_filter, TypeFilter, P4),

  % Optional `sort`
  add_option(P4, sort, Sort, P5),

  ckan(O1, related_list, P5, Related).


%! related_show(+Options:list(nvpair), +Id:atom, -Out:compound) is det.
% Return a single related item.
%
% @arg Options
% @arg Id the id of the related item to show
% @arg Out

related_show(O1, Id, Out):-
  ckan(O1, related_show, [id(Id)], Out).


%! revision_list(+Options:list(nvpair), -Revisions:list(atom)) is det.
% Return a list of the IDs of the site’s revisions.
%
% @arg Options
% @arg Revisions A list of IDs of the site's revisions.

revision_list(O1, Revisions):-
  ckan(O1, revision_list, [], Revisions).


%! site_read(+Options:list(nvpair)) is semidet.
% Suceeds if the CKAN site is readable?

site_read(O1):-
  ckan(O1, site_read, [], JSON),
  JSON == @(true).



% HELPER PREDICATES %

%! ckan(
%!   +Options:list(nvpair),
%!   +Action:atom,
%!   +Parameters:list(nvpair),
%!   -JSON:compound
%! ) is det.
% The following options are supported:
%   * =|api_key(+Key:atom)|=
%     An atomic API key.
%   * =|api_version(+Version:positive_integer)|=
%     Default: uninstantiated, using the server-side default.
%   * =|authority(+Authority:atom)|=
%     Default: =|datahub.io|=
%   * =|scheme(+Scheme:oneof([http,https]))|=
%     Default: =http=.
%
% The following actions are supported:
%   * =dashboard_activity_list=
%     Returns a list of activities from the user dashboard (API key required).
%   * =package_create=
%     Create a new dataset (API key required).
%   * =package_list=
%     Returns a list of the CKAN datasets.
%   * =package_search=
%     Search for CKAN datasets by name.
%     Requires the search option `q` to be set to the search term.
%     Optionally set the maximum number of returned search requests
%     with search option `rows` (with a positive integer value).
%   * =site_read=
%     Whether the CKAN site gives the user read access?
%
% @arg Options A list of name-value pairs.
% @arg Action The atomic name of a CKAN action.
% @arg Parameters A list of name-value pairs.
% @arg JSON A JSON-term.

:- json_object reply(
  error:error/2,
  help:atom,
  success:boolean
).
:- json_object reply(
  help:atom,
  result,
  success:boolean
).
:- json_object error(
  '__type':atom,
  message:atom
).

ckan(O1, Action, Parameters, Result):-
  % URL
  option(scheme(Scheme), O1),
  option(authority(Authority), O1),
  option(api_version(Version), O1, 3),
  uri_path([api,Version,action,Action], Path),
  uri_components(URL, uri_components(Scheme, Authority, Path, _, _)),

  % API key
  (
    option(api_key(Key), O1)
  ->
    HTTP_O1 = [authorization(Key)]
    %HTTP_O1 = [request_header('Authorization'=Key)]
  ;
    HTTP_O1 = []
  ),

  JSON_In = json(Parameters),
  merge_options(
    [
      method(post),
      post(json(JSON_In)),
      request_header('Content-Type'='application/json'),
      status_code(Status)
    ],
    HTTP_O1,
    HTTP_O2
  ),
  setup_call_cleanup(
    http_open(URL, Out, HTTP_O2),
    process_http(Status, Out, Result),
    close(Out)
  ).

process_http(200, Out, Result):- !,
  json_read(Out, JSON_Out),
  json_to_prolog(JSON_Out, Reply),
  process_ckan(Reply, Result).
process_http(Status, _, _):-
  debug(ckan, 'HTTP status code ~w', [Status]).

process_ckan(reply(error(Type,Message),Help,false), _):- !,
  throw(error(Type, context(Help, Message))).
process_ckan(reply(Help,Result,true), Result):-
  debug(ckan, 'Successful reply:\n~w', [Help]).


%! process_field_order_sort(
%!   +Field:oneof([name,packages]),
%!   +Order:atom,
%!   -Sort:atom
%! ) is det.

process_field_order_sort(Field1, Order1, Sort):-
  default(Field1, name, Field2),
  default(Order1, asc, Order2),
  atomic_list_concat([Field2,Order2], ' ', Sort).

%! process_limit_offset(
%!   +Options:list(nvpair),
%!   ?Limit:integer,
%!   ?Offset:integer,
%!   -Parameters:list(nvpair)
%! ) is det.
% The `offset` option is meaningless if there is no `limit` option.

process_limit_offset(_, Limit, Offset, []):-
  nonvar(Offset),
  var(Limit), !.
process_limit_offset(O1, Limit, Offset, P2):-
  % Parameter `limit`.
  add_option([], limit, Limit, P1),
  
  % Parameter `offset`.
  (
    option(deprecated(true), O1, false)
  ->
    ParameterName = page
  ;
    ParameterName = offset
  ),
  add_option(P1, ParameterName, Offset, P2).

