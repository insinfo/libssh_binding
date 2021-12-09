#include <stdlib.h>
#include <stdio.h>
#include <iostream>
#include <stdexcept>
#include <string>
#include <exception>
#pragma once
using namespace std;

//custom_exception.cpp
class CustomException : public std::exception {


public:
	CustomException(string msg) : std::exception(msg.c_str()) {


	}


	/*
	explicit invalid_argument(const string& _Message) : _Mybase(_Message.c_str()) {}
	explicit invalid_argument(const char* _Message) : _Mybase(_Message) {}*/


};

struct MyException : public std::exception
{
	const char* what() const throw ()
	{
		return "C++ Exception";
	}
};
