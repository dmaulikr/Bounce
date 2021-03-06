//
//  STPlaylistViewController.m
//  Bounce
//
//  Created by Paul Silvis on 3/30/13.
//  Copyright (c) 2013 Summertime. All rights reserved.
//

#import "STPlaylistViewController.h"
#import "STAppDelegate.h"
#import "Settings.h"
#import <Rdio/Rdio.h>
#import "UIFont+Bounce.h"
#import <QuartzCore/QuartzCore.h>

@interface STPlaylistViewController () <RdioDelegate, RDAPIRequestDelegate>

@end

@implementation STPlaylistViewController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    // Setup styles
    self.friendNameLabel.font = [UIFont openSansSemiboldWithSize:self.friendNameLabel.font.pointSize];
    self.friendNameLabel.textColor = [UIColor grayColor];
    self.friendNameLabel.text = [NSString stringWithFormat:@"%@ %@", [self.friend objectForKey:@"firstName"], [self.friend objectForKey:@"lastName"]];
    
    self.friendIconView.image = [self.friend objectForKey:@"downloadedIconImage"];
    self.friendIconView.contentMode = UIViewContentModeScaleAspectFill;
    self.friendIconView.clipsToBounds = YES;
    self.friendIconView.layer.cornerRadius = self.friendIconView.frame.size.width / 2;
    self.friendIconView.layer.masksToBounds = YES;
    
    self.currentArtistLabel.font = [UIFont openSansLightWithSize:self.currentArtistLabel.font.pointSize];
    self.currentArtistLabel.textColor = [UIColor grayColor];
    
    self.currentAlbumLabel.font = [UIFont openSansLightWithSize:self.currentAlbumLabel.font.pointSize];
    self.currentAlbumLabel.textColor = [UIColor grayColor];
    
    self.currentSongLabel.font = [UIFont openSansLightWithSize:self.currentSongLabel.font.pointSize];
    self.currentSongLabel.textColor = [UIColor grayColor];
    
    self.bounceQueueLabel.font = [UIFont openSansLightWithSize:self.bounceQueueLabel.font.pointSize];
    self.bounceQueueLabel.textColor = [UIColor grayColor];
    
    // Currently playing hidden
    self.currentlyPlayingView.frame = CGRectMake(self.currentlyPlayingView.frame.origin.x, -130.0, self.currentlyPlayingView.frame.size.width, self.currentlyPlayingView.frame.size.height);
    self.tableView.tableHeaderView.frame = CGRectMake(self.headerView.frame.origin.x, self.headerView.frame.origin.y, self.headerView.frame.size.width, self.headerView.frame.size.height - self.currentlyPlayingView.frame.size.height);
    
    [self findOrCreatePlaylist];
}

- (void) findOrCreatePlaylist
{
    NSMutableDictionary *params = [[NSMutableDictionary alloc] init];
    [params setObject:[[Settings settings] userKey] forKey:@"user"];
    [params setObject:@"tracks" forKey:@"extras"];
    [[STAppDelegate rdioInstance] callAPIMethod:@"getPlaylists" withParameters:params delegate:self];
}

- (void) createPlaylistWithName:(NSString*) playlistName
{
    NSMutableDictionary *params = [[NSMutableDictionary alloc] init];
    [params setObject:playlistName forKey:@"name"];
    [params setObject:@"Bounce Battle!" forKey:@"description"];
    [params setObject:@"" forKey:@"tracks"];
    [params setObject:@"tracks" forKey:@"extras"];
    [[STAppDelegate rdioInstance] callAPIMethod:@"createPlaylist" withParameters:params delegate:self];
}

#pragma mark -
#pragma mark RDAPIRequestDelegate

- (void)rdioRequest:(RDAPIRequest *)request didLoadData:(id)data
{
    //NSLog(@"%@", data);
    
    NSString *method = [request.parameters objectForKey:@"method"];
    
    if ([method isEqualToString: @"getPlaylists"]) {
        
        NSString *playlistName1 = [NSString stringWithFormat:@"Bounce %@ vs %@ %@",
                                   [[Settings settings] user],
                                   [self.friend objectForKey:@"firstName"],
                                   [self.friend objectForKey:@"lastName"]];
        
        NSString *playlistName2 = [NSString stringWithFormat:@"Bounce %@ %@ vs %@",
                                  [self.friend objectForKey:@"firstName"],
                                  [self.friend objectForKey:@"lastName"],
                                  [[Settings settings] user]];
        
        BOOL foundPlaylist = NO;
        for (NSDictionary* playlist in [data objectForKey:@"owned"]) {
            NSString* name = [playlist objectForKey:@"name"];
            
            if([name isEqual: playlistName1] || [name isEqual: playlistName2]) {
                foundPlaylist = YES;
                self.playlist = playlist;
                break;
            }
        }
        
        if (!foundPlaylist) {
            for (NSDictionary* playlist in [data objectForKey:@"collab"]) {
                NSString* name = [playlist objectForKey:@"name"];
                
                if([name isEqual: playlistName1] || [name isEqual: playlistName2]) {
                    foundPlaylist = YES;
                    self.playlist = playlist;
                    break;
                }
            }
        }
        
        if (!foundPlaylist) {
            NSLog(@"Creating new playlist");
            [self createPlaylistWithName:playlistName1];
        } else {
            self.tracks = [self.playlist objectForKey:@"tracks"];
            [self.tableView reloadData];
        }
    } else if ([method isEqualToString: @"createPlaylist"]) {
        self.playlist = data;
        self.tracks = [data objectForKey:@"tracks"];
        [self.tableView reloadData];
        
        // Update collaboration mode
        NSMutableDictionary *params = [[NSMutableDictionary alloc] init];
        [params setObject:[data objectForKey:@"key"] forKey:@"playlist"];
        [params setObject:[NSString stringWithFormat:@"%d",2] forKey:@"mode"];
        [[STAppDelegate rdioInstance] callAPIMethod:@"setPlaylistCollaborationMode" withParameters:params delegate:self];
    }
}

- (void)rdioRequest:(RDAPIRequest *)request didFailWithError:(NSError*)error {
    NSLog(@"error");
}

- (IBAction)backButtonPressed:(id)sender
{
    [[STAppDelegate rdioInstance].player stop];
    
    [self.navigationController popViewControllerAnimated:YES];
}

#pragma mark -
#pragma mark Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return [self.tracks count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *identifier = @"FriendsCell";
    
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:identifier];
    
    if (cell == nil) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:identifier];
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
    }
    
    NSMutableDictionary *track = [self.tracks objectAtIndex:indexPath.row];
    
    NSLog(@"%@", track);
    
    UILabel *name = [[UILabel alloc] initWithFrame:CGRectMake(80.0, 14.0, self.view.frame.size.width - 100.0, 20.0)];
    name.font = [UIFont openSansSemiboldWithSize:16.0];
    name.textColor = [UIColor grayColor];
    name.text = [track objectForKey:@"name"];
    [cell.contentView addSubview:name];
    
    UILabel *description = [[UILabel alloc] initWithFrame:CGRectMake(80.0, 34.0, self.view.frame.size.width - 100.0, 20.0)];
    description.font = [UIFont openSansLightWithSize:13.0];
    description.textColor = [UIColor grayColor];
    description.text = [NSString stringWithFormat:@"%@ - %@", [track objectForKey:@"artist"], [track objectForKey:@"album"]];
    [cell.contentView addSubview:description];
    
    if ([track objectForKey:@"downloadedIconImage"]) {
        UIImageView *imageView = [[UIImageView alloc] initWithFrame:CGRectMake(20.0, 13.0, 40.0, 40.0)];
        imageView.image = [track objectForKey:@"downloadedIconImage"];
        imageView.contentMode = UIViewContentModeScaleAspectFill;
        imageView.clipsToBounds = YES;
        imageView.layer.cornerRadius = imageView.frame.size.width / 2;
        imageView.layer.masksToBounds = YES;
        [cell.contentView addSubview:imageView];
    } else {
        __weak STPlaylistViewController *weakSelf = self;
        NSURL *imageURL = [NSURL URLWithString:[track objectForKey:@"icon"]];
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
            NSData *imageData = [NSData dataWithContentsOfURL:imageURL];
            dispatch_async(dispatch_get_main_queue(), ^{
                NSUInteger index = [weakSelf.tracks indexOfObject:track];
                if(index == NSNotFound)
                    return;
                [[weakSelf.tracks objectAtIndex:index] setObject:[UIImage imageWithData:imageData] forKey:@"downloadedIconImage"];
                [weakSelf.tableView reloadRowsAtIndexPaths:@[[NSIndexPath indexPathForRow:index inSection:0]] withRowAnimation:UITableViewRowAnimationNone];
            });
        });
    }
    
    return cell;
}

#pragma mark -
#pragma mark Table view delegate

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return 65.0;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    NSMutableDictionary *track = [self.tracks objectAtIndex:indexPath.row];
    [self playTrack:track];
}

- (void)playTrack:(NSDictionary *)track
{
    [[STAppDelegate rdioInstance].player playSource:[track objectForKey:@"key"]];
    
    self.currentSongLabel.text = [track objectForKey:@"name"];
    self.currentArtistLabel.text = [track objectForKey:@"artist"];
    self.currentAlbumLabel.text = [track objectForKey:@"album"];
    
    if ([track objectForKey:@"downloadedIconImage"]) {
        self.currentSongImageView.image = [track objectForKey:@"downloadedIconImage"];
        self.currentSongImageView.contentMode = UIViewContentModeScaleAspectFill;
        self.currentSongImageView.clipsToBounds = YES;
        self.currentSongImageView.layer.cornerRadius = self.currentSongImageView.frame.size.width / 2;
        self.currentSongImageView.layer.masksToBounds = YES;
    }

    // Slide down
    if (self.currentlyPlayingView.frame.origin.y != 38.0) {
        [UIView animateWithDuration:0.5 animations:^{
            self.currentlyPlayingView.frame = CGRectMake(self.currentlyPlayingView.frame.origin.x, 38.0, self.currentlyPlayingView.frame.size.width, self.currentlyPlayingView.frame.size.height);
            self.tableView.tableHeaderView.frame = CGRectMake(self.headerView.frame.origin.x, self.headerView.frame.origin.y, self.headerView.frame.size.width, self.headerView.frame.size.height + self.currentlyPlayingView.frame.size.height);
            self.tableView.tableHeaderView = self.headerView;
        } completion:^(BOOL completed){
            [self.tableView reloadData];
        }];
    }
}

@end
