import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';

class LoginTextField extends StatefulWidget {
  // final String password;
  final String svgPath; //
  final String inputType;

  final Function(String) onTextChanged;

  const LoginTextField(
      {super.key,
      required this.svgPath,
      required this.inputType,
      required this.onTextChanged});

  @override
  State<LoginTextField> createState() => _LoginTextFieldState();
}

class _LoginTextFieldState extends State<LoginTextField> {
  bool _obscureText = true; // Initially password is obscured
  String _passwordValue = '';

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 55,
      padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 4.0),
      decoration: BoxDecoration(
          border: Border.all(
            color: Colors.grey,
          ),
          borderRadius: BorderRadius.circular(6.0)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SvgPicture.asset(widget.svgPath),
          const VerticalDivider(
            color: Colors.grey,
            thickness: 1.0,
            indent: 8.0,
            endIndent: 8.0,
          ),
          Expanded(
              flex: 1,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.inputType,
                    style: const TextStyle(
                        color: Color(0xFF0F7D40),
                        fontSize: 11.1,
                        fontWeight: FontWeight.w500),
                  ),
                  SizedBox(
                    height: 27.65,
                    child: TextField(
                      style: const TextStyle(
                          color: Color(0xFF000E08),
                          fontSize: 19.2,
                          fontWeight: FontWeight
                              .w500 // Adjust font size as needed (smaller values for smaller font)
                          ),
                      onChanged: (value) {
                        setState(() {
                          _passwordValue = value;
                        });
                        widget.onTextChanged(value);
                      },
                      obscureText:
                          widget.inputType == 'Password' ? _obscureText : false,
                      decoration: InputDecoration(
                        hintText: "Enter your ${widget.inputType}",
                        hintStyle: const TextStyle(fontSize: 16.0),
                        border: const OutlineInputBorder(
                          borderSide: BorderSide.none, // Removes the border
                        ),
                        contentPadding: EdgeInsets.zero,
                        filled: false,
                      ),
                    ),
                  ),
                ],
              )),
          if (_passwordValue.isNotEmpty && widget.inputType == 'Password')
            IconButton(
              icon: Icon(
                _obscureText ? Icons.visibility : Icons.visibility_off,
              ),
              onPressed: () {
                setState(() {
                  _obscureText = !_obscureText; // Toggle obscureText value
                });
              },
            ),
        ],
      ),
    );
  }
}
