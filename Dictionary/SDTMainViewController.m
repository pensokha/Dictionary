//
//  MainViewController.m
//  Dictionary
//
//  Created by Feng Ye on 11/18/11.
//  Copyright (c) 2011 @forresty. All rights reserved.
//

#import "SDTMainViewController.h"
#import "SDTLookupHistory.h"
#import "SDTLookupRequest.h"
#import "SDTLookupResponse.h"
#import "SDTDictionaryTermCell.h"
#import "SDTDictionaryTableHeaderView.h"
#import "SDTDictionaryViewDefinitions.h"


@interface SDTMainViewController ()

@property UISearchBar *searchBar;
@property UITableView *lookupHistoryTableView;
@property UISearchDisplayController *dictionarySearchDisplayController;

@property SDTLookupHistory *lookupHistory;
@property SDTLookupRequest *lookupRequest;
@property SDTLookupResponse *lookupResponse;

@end


@implementation SDTMainViewController


# pragma mark - View lifecycle


- (void)viewDidLoad {
  [super viewDidLoad];

  _lookupHistory = [SDTLookupHistory sharedInstance];
  _lookupRequest = [[SDTLookupRequest alloc] init];
  _lookupResponse = [SDTLookupResponse responseWithProgressState:DictionaryLookupProgressStateIdle terms:@[]];

  [self buildViews];
}


- (void)buildViews {
  _searchBar = [[UISearchBar alloc] init];
  _lookupHistoryTableView = [[UITableView alloc] init];
  _dictionarySearchDisplayController = [[UISearchDisplayController alloc] initWithSearchBar:self.searchBar contentsController:self];

  [self buildSearchBar];
  [self buildLookupHistoryTableView];
  [self buildSearchDisplayController];
  [self setupViewConstraints];
  [self setupUIAppearances];
}


- (void)buildSearchBar {
  self.searchBar.delegate = self;
  self.searchBar.autocapitalizationType = UITextAutocapitalizationTypeNone;
  [self.searchBar sizeToFit];
}


- (void)buildLookupHistoryTableView {
  [self.lookupHistoryTableView setTranslatesAutoresizingMaskIntoConstraints:NO];
  self.lookupHistoryTableView.dataSource = self;
  self.lookupHistoryTableView.delegate = self;
  self.lookupHistoryTableView.tableHeaderView = self.searchBar;

  [self.view addSubview:self.lookupHistoryTableView];
}


- (void)buildSearchDisplayController {
  self.dictionarySearchDisplayController.delegate = self;
  self.dictionarySearchDisplayController.searchResultsDataSource = self;
  self.dictionarySearchDisplayController.searchResultsDelegate = self;
}


- (void)setupViewConstraints {
  UITableView *historyTableView = self.lookupHistoryTableView;
  NSDictionary *views = NSDictionaryOfVariableBindings(historyTableView, self.view);
  [self.view addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"|[historyTableView]|" options:0 metrics:nil views:views]];
  [self.view addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|[historyTableView]|" options:0 metrics:nil views:views]];
}


- (void)setupUIAppearances {
  [[UISearchBar appearance] setTintColor:DICTIONARY_BASIC_TINT_COLOR];

  // http://stackoverflow.com/questions/11572372/modifying-uisearchbar-cancel-button-font-text-color-and-style
  NSDictionary *attributes = @{ UITextAttributeTextColor: DICTIONARY_BASIC_TEXT_COLOR,
                          UITextAttributeTextShadowColor: DICTIONARY_BASIC_TINT_COLOR,
                         UITextAttributeTextShadowOffset: [NSValue valueWithUIOffset:UIOffsetMake(0, -1)] };
  [[UIBarButtonItem appearanceWhenContainedIn:[UISearchBar class], nil] setTitleTextAttributes:attributes forState:UIControlStateNormal];

  UITableViewHeaderFooterView *headerViewProxy = [UITableViewHeaderFooterView appearance];
  headerViewProxy.tintColor = DICTIONARY_BASIC_TEXT_COLOR;

  UILabel *labelProxy = [UILabel appearanceWhenContainedIn:[UITableViewHeaderFooterView class], nil];
  labelProxy.textColor = DICTIONARY_BASIC_TINT_COLOR;
  labelProxy.font = [UIFont fontWithName:@"Helvetica-Bold" size:16];
  labelProxy.shadowOffset = CGSizeZero;
}


# pragma mark - internal


- (NSArray *)indexPathsFromOffset:(NSUInteger)offset count:(NSUInteger)count {
  NSMutableArray * indexPaths = [[NSMutableArray alloc] initWithCapacity:count];

  for (int i = 0; i < count; i++) {
    [indexPaths addObject:[NSIndexPath indexPathForRow:i + offset inSection:0]];
  }

  return indexPaths;
}


# pragma mark - history


- (void)clearHistory {
  [[NSOperationQueue mainQueue] addOperationWithBlock:^{
    [self.lookupHistoryTableView beginUpdates];
    [self.lookupHistoryTableView deleteRowsAtIndexPaths:[self indexPathsFromOffset:0 count:self.lookupHistory.count] withRowAnimation:UITableViewRowAnimationTop];
    [self.lookupHistory clear];
    [self.lookupHistoryTableView endUpdates];
  }];

  [[NSOperationQueue mainQueue] addOperationWithBlock:^{
    [self.lookupHistoryTableView reloadData];
    [self.lookupHistoryTableView setContentOffset:CGPointZero animated:YES];
  }];
}


# pragma mark - UI presentation


- (void)showDefinitionForTerm:(NSString *)term {
  [[NSOperationQueue mainQueue] addOperationWithBlock:^{
    [self.lookupHistory addLookupHistoryWithTerm:term];
    [self.lookupHistoryTableView reloadData];
  }];

  UIReferenceLibraryViewController *referenceLibraryViewController = [[UIReferenceLibraryViewController alloc] initWithTerm:term];

  [self presentViewController:referenceLibraryViewController animated:YES completion:NULL];
}


# pragma mark - UITableViewDataSource


- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
  SDTDictionaryTermCell *cell = [tableView dequeueReusableCellWithIdentifier:kDictionaryTermCellID];

  if (!cell) {
    cell = [[SDTDictionaryTermCell alloc] init];
  }

  if (tableView == self.searchDisplayController.searchResultsTableView) {
    [self makeSearchResultCell:cell forRowAtIndexPath:indexPath];
  } else {
    [self makeHistoryCell:cell forRowAtIndexPath:indexPath];
  }

  return cell;
}


- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
  return 1;
}


- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
  if (tableView == self.searchDisplayController.searchResultsTableView) {
    switch (self.lookupResponse.lookupState) {
      case DictionaryLookupProgressStateIdle:
        return 0;
      case DictionaryLookupProgressStateLookingUpCompletionsButNoResultYet:
      case DictionaryLookupProgressStateFoundNoCompletionsLookingUpGuessesButNoResultsYet:
        return 1;
      case DictionaryLookupProgressStateHasPartialResults:
      case DictionaryLookupProgressStateFinishedWithCompletions:
      case DictionaryLookupProgressStateFinishedWithGuesses:
        return self.lookupResponse.terms.count;
      case DictionaryLookupProgressStateFinishedWithNoResultsAtAll:
        return 1;
      default:
        return 0;
    }
  } else {
    return self.lookupHistory.count + 1;
  }
}


# pragma mark delete history


- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
  if (tableView == self.lookupHistoryTableView && self.lookupHistory.count > 0 && indexPath.row < self.lookupHistory.count) {
    return YES;
  }

  return NO;
}


- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
  if (tableView == self.lookupHistoryTableView && editingStyle == UITableViewCellEditingStyleDelete) {
    if (self.lookupHistory.count > 1) {
      [self.lookupHistoryTableView beginUpdates];
      [self.lookupHistory removeLookupHistoryAtIndex:indexPath.row];
      [self.lookupHistoryTableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationFade];
      [self.lookupHistoryTableView endUpdates];
    } else {
      [self.lookupHistory removeLookupHistoryAtIndex:indexPath.row];
      [self.lookupHistoryTableView reloadData];
    }
  }
}

# pragma mark private


- (void)makeHistoryCell:(SDTDictionaryTermCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath {
  if (self.lookupHistory.count == 0) {
    [cell changeToType:DictionaryTableViewCellTypeDisabled withText:@"No history"];
  } else if (indexPath.row == self.lookupHistory.count) {
    [cell changeToType:DictionaryTableViewCellTypeAction withText:@"Clear History"];
  } else {
    [cell changeToType:DictionaryTableViewCellTypeNormal withText:[self.lookupHistory[indexPath.row] description]];
  }
}


- (void)makeSearchResultCell:(SDTDictionaryTermCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath {
  switch (self.lookupResponse.lookupState) {
    case DictionaryLookupProgressStateLookingUpCompletionsButNoResultYet:
      return [cell changeToType:DictionaryTableViewCellTypeDisabled withText:@"Looking up..."];
    case DictionaryLookupProgressStateFoundNoCompletionsLookingUpGuessesButNoResultsYet:
      return [cell changeToType:DictionaryTableViewCellTypeDisabled withText:@"No results, guessing..."];
    case DictionaryLookupProgressStateHasPartialResults:
    case DictionaryLookupProgressStateFinishedWithCompletions:
    case DictionaryLookupProgressStateFinishedWithGuesses:
      return [cell changeToType:DictionaryTableViewCellTypeNormal withText:self.lookupResponse.terms[indexPath.row]];
    default:
      return [cell changeToType:DictionaryTableViewCellTypeDisabled withText:@"No result"];
  }
}


# pragma mark - UITableViewDelegate

# pragma mark view customization


- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section {
  if (tableView == self.lookupHistoryTableView) {
    return [SDTDictionaryTableHeaderView viewWithText:@"History"];
  }
  if (self.lookupResponse.lookupState == DictionaryLookupProgressStateFinishedWithGuesses) {
    return [SDTDictionaryTableHeaderView viewWithText:@"Did you mean?"];
  }

  return nil;
}


- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
  UIView *headerView = [self tableView:tableView viewForHeaderInSection:section];

  return headerView.bounds.size.height;
}


# pragma mark user actions


- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
  [tableView deselectRowAtIndexPath:indexPath animated:YES];

  if (tableView == self.searchDisplayController.searchResultsTableView) {
    switch (self.lookupResponse.lookupState) {
      case DictionaryLookupProgressStateHasPartialResults:
      case DictionaryLookupProgressStateFinishedWithCompletions:
      case DictionaryLookupProgressStateFinishedWithGuesses:
        return [self showDefinitionForTerm:self.lookupResponse.terms[indexPath.row]];
      default:
        return;
    }
  } else {
    if (self.lookupHistory.count == 0) {
      // empty history, do nothing
    } else if (indexPath.row == self.lookupHistory.count) {
      [self clearHistory];
    } else {
      [self showDefinitionForTerm:[self.lookupHistory[indexPath.row] description]];
    }
  }
}


# pragma mark - UISearchDisplayDelegate


- (BOOL)searchDisplayController:(UISearchDisplayController *)searchDisplayController shouldReloadTableForSearchString:(NSString *)searchString {
  if (searchString.length < 1) {
    return NO;
  }

  [self.lookupRequest startLookingUpDictionaryWithTerm:searchString existingTerms:self.lookupResponse.terms progressBlock:^(SDTLookupResponse *response) {
    [[NSOperationQueue mainQueue] addOperationWithBlock:^{
      self.lookupResponse = response;
      [self.searchDisplayController.searchResultsTableView reloadData];
    }];
  }];

  return NO;
}


# pragma mark - UISearchBarDelegate


- (void)searchBarSearchButtonClicked:(UISearchBar *)searchBar {
  if (searchBar.text.length > 0 && self.lookupResponse.terms.count > 0 && [searchBar.text isEqualToString:self.lookupResponse.terms[0]]) {
    [self showDefinitionForTerm:searchBar.text];
  }
}


@end