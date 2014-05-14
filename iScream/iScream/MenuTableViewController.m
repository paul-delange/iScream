//
//  MenuTableViewController.m
//  iScream
//
//  Created by Paul de Lange on 15/05/2014.
//  Copyright (c) 2014 Gilmert Bentley. All rights reserved.
//

#import "MenuTableViewController.h"

typedef NS_ENUM(NSUInteger, kMenuTableViewItem) {
    kMenuTableViewItemInsectGame = 0,
    kMenuTableViewItemWomanGame,
    kMenuTableViewItemStatuesGame,
    kMenuTableViewItemStareGame,
    kMenuTableViewItemCount
};

@interface MenuTableViewController () <UITableViewDelegate, UITableViewDataSource>

@end

@implementation MenuTableViewController

#pragma mark - UIViewController
- (void)viewDidLoad
{
    [super viewDidLoad];
    self.title = @"Game ideas";
}

#pragma mark - UITableViewDataSource
- (NSInteger) tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return kMenuTableViewItemCount;
}

- (UITableViewCell*) tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell* cell = [tableView dequeueReusableCellWithIdentifier: @"MenuTableView" forIndexPath: indexPath];
    
    switch (indexPath.row) {
        case kMenuTableViewItemInsectGame:
            cell.textLabel.text = @"Insect Game";
            cell.detailTextLabel.text = @"When you close your eyes, cockroaches appear. When you open your eyes, you squash them with your finger";
            break;
        case kMenuTableViewItemWomanGame:
            cell.textLabel.text = @"Adult Game";
            cell.detailTextLabel.text = @"When you look away the woman is slowly revealed. When you look back, she covers up.";
            break;
        case kMenuTableViewItemStatuesGame:
            cell.textLabel.text = @"Statues";
            cell.detailTextLabel.text = @"Children's game where you are not allowed to move (become a statue) when the main person looks at you.";
            break;
        case kMenuTableViewItemStareGame:
            cell.textLabel.text = @"Who can stare the longest?";
            cell.detailTextLabel.text = @"Multipeer game where you must stare at the other person and see who blinks or looks away first.";
            break;
        default:
            break;
    }
    
    return cell;
}

#pragma mark - UITableViewDelegate
- (CGFloat) tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return 100.;
}

@end
