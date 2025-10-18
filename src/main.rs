mod artwork;

use artwork::HORSES;
use clap::Parser;
use crossterm::{
    ExecutableCommand,
    cursor::{Hide, Show},
    event::{poll, read, Event, KeyCode},
    execute,
    terminal::{self, Clear, ClearType, EnterAlternateScreen, LeaveAlternateScreen, size},
};
use rand::Rng;
use std::io::{Write, stdout};
use std::thread;
use std::time::Duration;

#[derive(Parser)]
#[command(name = "horse")]
#[command(version = env!("CARGO_PKG_VERSION"))]
#[command(about = "Displays animated horses scrolling across your terminal", long_about = None)]
struct Cli {}

// Frame data structure
struct Frame {
    content: &'static str,
    width: u16,
    height: u16,
    x: i32, // horizontal position
}

impl Frame {
    fn new(content: &'static str, initial_x: i32) -> Self {
        let lines: Vec<&str> = content.lines().collect();
        let height = lines.len() as u16;
        let width = lines.iter().map(|l| l.len()).max().unwrap_or(0) as u16;

        Frame {
            content,
            width,
            height,
            x: initial_x,
        }
    }

    // Helper method to get the right edge position
    fn right_edge(&self) -> i32 {
        self.x + self.width as i32
    }

    // Helper method to scroll the frame
    fn scroll(&mut self, amount: i32) {
        self.x += amount;
    }

    // Helper method to check if frame is fully off-screen to the left
    fn is_offscreen_left(&self) -> bool {
        self.right_edge() < 0
    }
}

const SPACING: i32 = 10; // Space between frames
const SCROLL_SPEED: i32 = 1; // Pixels per tick
const FPS: u64 = 30; // Frames per second

// Cleanup function to restore terminal state and exit
fn cleanup_and_exit() {
    let mut stdout = std::io::stdout();
    let _ = terminal::disable_raw_mode();
    let _ = execute!(stdout, Show, LeaveAlternateScreen);
    std::process::exit(0);
}

// Get a random horse that's different from the last one
fn random_horse(last_content: Option<&'static str>) -> &'static str {
    let mut rng = rand::rng();

    if HORSES.len() == 1 {
        return HORSES[0];
    }

    let mut next = HORSES[rng.random_range(0..HORSES.len())];
    while Some(next) == last_content {
        next = HORSES[rng.random_range(0..HORSES.len())];
    }
    next
}

fn main() {
    // Parse command-line arguments (handles --version automatically)
    let _cli = Cli::parse();

    let mut stdout = stdout();

    // Enable raw mode for keyboard input
    terminal::enable_raw_mode().expect("Failed to enable raw mode");

    // Enter alternate screen and hide cursor
    let _ = execute!(stdout, EnterAlternateScreen, Hide);

    // Set up Ctrl+C handler to restore cursor and leave alternate screen
    ctrlc::set_handler(|| {
        cleanup_and_exit();
    })
    .expect("Error setting Ctrl+C handler");

    // Spawn background thread to monitor for 'q', 'Esc', and Ctrl+C key presses
    std::thread::spawn(|| {
        loop {
            if let Ok(true) = poll(Duration::from_millis(100)) {
                if let Ok(Event::Key(key)) = read() {
                    match key.code {
                        KeyCode::Char('q') | KeyCode::Char('Q') | KeyCode::Esc => {
                            cleanup_and_exit();
                        }
                        KeyCode::Char('c') if key.modifiers.contains(crossterm::event::KeyModifiers::CONTROL) => {
                            cleanup_and_exit();
                        }
                        _ => {}
                    }
                }
            }
        }
    });

    let mut frames: Vec<Frame> = Vec::new();
    let mut last_frame_content: Option<&'static str> = None;

    loop {
        let (term_width, term_height) = size().expect("Failed to get terminal size");

        // Check if we need a new frame on the right
        let needs_new_frame = if let Some(rightmost) = frames.last() {
            // If the rightmost frame is getting close to being visible, add a new one
            rightmost.right_edge() < term_width as i32 + (term_width as i32 / 2)
        } else {
            // No frames yet, definitely need one
            true
        };

        if needs_new_frame {
            let new_content = random_horse(last_frame_content);
            let new_x = frames
                .last()
                .map(|f| f.right_edge() + SPACING)
                .unwrap_or(term_width as i32);
            frames.push(Frame::new(new_content, new_x));
            last_frame_content = Some(new_content);
        }

        // Move cursor to home and clear from cursor down (not scrollback)
        stdout
            .execute(crossterm::cursor::MoveTo(0, 0))
            .expect("Failed to move cursor");
        stdout
            .execute(Clear(ClearType::FromCursorDown))
            .expect("Failed to clear terminal");

        // Render each frame
        for frame in &frames {
            // Calculate vertical center for this specific frame
            let y_start = ((term_height as i32 - frame.height as i32) / 2).max(0);

            for (line_idx, line) in frame.content.lines().enumerate() {
                let y = y_start + line_idx as i32;

                // Only render if line is within terminal bounds
                if y >= 0 && y < term_height as i32 {
                    // Check if any part of the line is visible horizontally
                    if frame.x < term_width as i32 && frame.x + line.len() as i32 > 0 {
                        // Calculate visible portion of the line
                        let start_char = if frame.x < 0 {
                            (-frame.x as usize).min(line.len())
                        } else {
                            0
                        };

                        let end_char = if frame.x + line.len() as i32 > term_width as i32 {
                            ((term_width as i32 - frame.x) as usize).min(line.len())
                        } else {
                            line.len()
                        };

                        if start_char < end_char && start_char < line.len() {
                            let visible_part = &line[start_char..end_char];
                            let x_pos = if frame.x < 0 { 0 } else { frame.x as u16 };

                            stdout
                                .execute(crossterm::cursor::MoveTo(x_pos, y as u16))
                                .expect("Failed to move cursor");
                            print!("{}", visible_part);
                        }
                    }
                }
            }
        }

        stdout.flush().expect("Failed to flush stdout");

        // Update positions (scroll left)
        for frame in &mut frames {
            frame.scroll(-SCROLL_SPEED);
        }

        // Event 2: Remove frames that have completely exited the left side
        frames.retain(|frame| !frame.is_offscreen_left());

        thread::sleep(Duration::from_millis(1000 / FPS));
    }
}
