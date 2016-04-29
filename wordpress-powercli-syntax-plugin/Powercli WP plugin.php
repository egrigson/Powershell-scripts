<?php
/*
Plugin Name: SyntaxHighlighter Evolved: PowerCLI Brush
Plugin URI: http://www.vexperienced.co.uk/?p=1724
Description: Adds support for the PowerCLI language to the SyntaxHighlighter Evolved plugin.
Author: Ed Grigson
Version: 1.0.0
Author URI: http://www.vExperienced.co.uk/
*/
 
// SyntaxHighlighter Evolved doesn't do anything until early in the "init" hook, so best to wait until after that
add_action( 'init', 'syntaxhighlighter_powercli_regscript' );
 
// Tell SyntaxHighlighter Evolved about this new language/brush
add_filter( 'syntaxhighlighter_brushes', 'syntaxhighlighter_powercli_addlang' );
 
// Register the brush file with WordPress
function syntaxhighlighter_powercli_regscript() {
    wp_register_script( 'syntaxhighlighter-brush-powercli', plugins_url( 'shBrushPowerCLI.js', __FILE__ ), array('syntaxhighlighter-core'), '1.0.0' );
}
 
// Filter SyntaxHighlighter Evolved's language array
function syntaxhighlighter_powercli_addlang( $brushes ) {
    $brushes['powercli'] = 'powercli';
    $brushes['pcli'] = 'powercli';
 
    return $brushes;
}
 
?>