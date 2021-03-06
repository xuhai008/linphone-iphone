/*
 * Copyright (c) 2010-2019 Belledonne Communications SARL.
 *
 * This file is part of linphone-iphone
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program. If not, see <http://www.gnu.org/licenses/>.
 */

#import "CallSideMenuView.h"
#import "LinphoneManager.h"
#import "PhoneMainView.h"

@implementation CallSideMenuView {
	NSTimer *updateTimer;
}

#pragma mark - ViewController Functions

- (void)viewWillAppear:(BOOL)animated {
	[super viewWillAppear:animated];
	if (updateTimer != nil) {
		[updateTimer invalidate];
	}
	updateTimer = [NSTimer scheduledTimerWithTimeInterval:1
												   target:self
												 selector:@selector(updateStats:)
												 userInfo:nil
												  repeats:YES];

	[self updateStats:nil];
}

- (void)viewWillDisappear:(BOOL)animated {
	[super viewWillDisappear:animated];
	if (updateTimer != nil) {
		[updateTimer invalidate];
		updateTimer = nil;
	}
}

- (IBAction)onLateralSwipe:(id)sender {
	[PhoneMainView.instance.mainViewController hideSideMenu:YES];
}

+ (NSString *)iceToString:(LinphoneIceState)state {
	switch (state) {
		case LinphoneIceStateNotActivated:
			return NSLocalizedString(@"Not activated", @"ICE has not been activated for this call");
			break;
		case LinphoneIceStateFailed:
			return NSLocalizedString(@"Failed", @"ICE processing has failed");
			break;
		case LinphoneIceStateInProgress:
			return NSLocalizedString(@"In progress", @"ICE process is in progress");
			break;
		case LinphoneIceStateHostConnection:
			return NSLocalizedString(@"Direct connection",
									 @"ICE has established a direct connection to the remote host");
			break;
		case LinphoneIceStateReflexiveConnection:
			return NSLocalizedString(
				@"NAT(s) connection",
				@"ICE has established a connection to the remote host through one or several NATs");
			break;
		case LinphoneIceStateRelayConnection:
			return NSLocalizedString(@"Relay connection", @"ICE has established a connection through a relay");
			break;
	}
}

+ (NSString*)afinetToString:(int)remote_family {
	return (remote_family == LinphoneAddressFamilyUnspec) ? @"Unspecified":(remote_family == LinphoneAddressFamilyInet) ? @"IPv4" : @"IPv6";
}

+ (NSString *)mediaEncryptionToString:(LinphoneMediaEncryption)enc {
	switch (enc) {
		case LinphoneMediaEncryptionDTLS:
			return @"DTLS";
		case LinphoneMediaEncryptionSRTP:
			return @"SRTP";
		case LinphoneMediaEncryptionZRTP:
			return @"ZRTP";
		case LinphoneMediaEncryptionNone:
			break;
	}
	return NSLocalizedString(@"None", nil);
}

- (NSString *)updateStatsForCall:(LinphoneCall *)call stream:(LinphoneStreamType)stream {
	NSMutableString *result = [[NSMutableString alloc] init];
	const PayloadType *payload = NULL;
	const LinphoneCallStats *stats;
	const LinphoneCallParams *params = linphone_call_get_current_params(call);
	NSString *name;

	switch (stream) {
		case LinphoneStreamTypeAudio:
			name = @"Audio";
			payload = linphone_call_params_get_used_audio_codec(params);
			stats = linphone_call_get_audio_stats(call);
			break;
		case LinphoneStreamTypeText:
			name = @"Text";
			payload = linphone_call_params_get_used_text_codec(params);
			stats = linphone_call_get_text_stats(call);
			break;
		case LinphoneStreamTypeVideo:
			name = @"Video";
			payload = linphone_call_params_get_used_video_codec(params);
			stats = linphone_call_get_video_stats(call);
			break;
		case LinphoneStreamTypeUnknown:
			break;
	}
	if (payload == NULL) {
		return result;
	}

	[result appendString:@"\n"];
	[result appendString:name];
	[result appendString:@"\n"];

	[result appendString:[NSString stringWithFormat:@"Codec: %s/%iHz", payload->mime_type, payload->clock_rate]];
	if (stream == LinphoneStreamTypeAudio) {
		[result appendString:[NSString stringWithFormat:@"/%i channels", payload->channels]];
	}
	[result appendString:@"\n"];
	// Encoder & decoder descriptions
	const char *enc_desc = ms_factory_get_encoder(linphone_core_get_ms_factory(LC), payload->mime_type)->text;
	const char *dec_desc = ms_factory_get_decoder(linphone_core_get_ms_factory(LC), payload->mime_type)->text;
	if (strcmp(enc_desc, dec_desc) == 0) {
		[result appendString:[NSString stringWithFormat:@"Encoder/Decoder: %s", enc_desc]];
		[result appendString:@"\n"];
	} else {
		[result appendString:[NSString stringWithFormat:@"Encoder: %s", enc_desc]];
		[result appendString:@"\n"];
		[result appendString:[NSString stringWithFormat:@"Decoder: %s", dec_desc]];
		[result appendString:@"\n"];
	}

	if (stats != NULL) {
		[result appendString:[NSString stringWithFormat:@"Download bandwidth: %1.1f kbits/s",
														linphone_call_stats_get_download_bandwidth(stats)]];
		[result appendString:@"\n"];
		[result appendString:[NSString stringWithFormat:@"Upload bandwidth: %1.1f kbits/s",
														linphone_call_stats_get_upload_bandwidth(stats)]];
		[result appendString:@"\n"];
        if (stream == LinphoneStreamTypeVideo) {
            /*[result appendString:[NSString stringWithFormat:@"Estimated download bandwidth: %1.1f kbits/s",
                                  linphone_call_stats_get_estimated_download_bandwidth(stats)]];
            [result appendString:@"\n"];*/
        }
		[result
			appendString:[NSString stringWithFormat:@"ICE state: %@",
													[self.class iceToString:linphone_call_stats_get_ice_state(stats)]]];
		[result appendString:@"\n"];
		[result
			appendString:[NSString
							 stringWithFormat:@"Afinet: %@",
											  [self.class afinetToString:linphone_call_stats_get_ip_family_of_remote(
																			 stats)]]];
		[result appendString:@"\n"];

		// RTP stats section (packet loss count, etc)
		const rtp_stats_t rtp_stats = *linphone_call_stats_get_rtp_stats(stats);
		[result
			appendString:[NSString stringWithFormat:
									   @"RTP packets: %llu total, %lld cum loss, %llu discarded, %llu OOT, %llu bad",
									   rtp_stats.packet_recv, rtp_stats.cum_packet_loss, rtp_stats.discarded,
									   rtp_stats.outoftime, rtp_stats.bad]];
		[result appendString:@"\n"];
		[result appendString:[NSString stringWithFormat:@"Sender loss rate: %.2f%%",
														linphone_call_stats_get_sender_loss_rate(stats)]];
		[result appendString:@"\n"];
		[result appendString:[NSString stringWithFormat:@"Receiver loss rate: %.2f%%",
														linphone_call_stats_get_receiver_loss_rate(stats)]];
		[result appendString:@"\n"];

		if (stream == LinphoneStreamTypeVideo) {
			const LinphoneVideoDefinition *recv_definition = linphone_call_params_get_received_video_definition(params);
			const LinphoneVideoDefinition *sent_definition = linphone_call_params_get_sent_video_definition(params);
			float sentFPS = linphone_call_params_get_sent_framerate(params);
			float recvFPS = linphone_call_params_get_received_framerate(params);
			[result appendString:[NSString stringWithFormat:@"Sent video resolution: %dx%d (%.1fFPS)", linphone_video_definition_get_width(sent_definition),
															linphone_video_definition_get_height(sent_definition), sentFPS]];
			[result appendString:@"\n"];
			[result appendString:[NSString stringWithFormat:@"Received video resolution: %dx%d (%.1fFPS)",
								  linphone_video_definition_get_width(recv_definition),
								  linphone_video_definition_get_height(recv_definition), recvFPS]];
			[result appendString:@"\n"];
		}
	}
	return result;
}

- (void)updateStats:(NSTimer *)timer {
	LinphoneCall *call = linphone_core_get_current_call(LC);

	if (!call) {
		_statsLabel.text = NSLocalizedString(@"No call in progress", nil);
		return;
	}

	NSMutableString *stats = [[NSMutableString alloc] init];

	LinphoneMediaEncryption enc = linphone_call_params_get_media_encryption(linphone_call_get_current_params(call));
	if (enc != LinphoneMediaEncryptionNone) {
		[stats appendString:[NSString
								stringWithFormat:@"Call encrypted using %@", [self.class mediaEncryptionToString:enc]]];
	}

	[stats appendString:[self updateStatsForCall:call stream:LinphoneStreamTypeAudio]];
	[stats appendString:[self updateStatsForCall:call stream:LinphoneStreamTypeVideo]];
	[stats appendString:[self updateStatsForCall:call stream:LinphoneStreamTypeText]];

	_statsLabel.text = stats;
}

@end
